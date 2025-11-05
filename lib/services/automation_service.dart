import 'dart:typed_data';
import 'package:bixat_key_mouse/bixat_key_mouse.dart';
import 'package:screen_capturer/screen_capturer.dart';
import 'package:image/image.dart' as img;
import 'vision_service.dart';
import 'shortcuts_service.dart';

/// Automation Functions that will be called by Gemini
class AutomationService {
  final ScreenCapturer _screenCapturer = ScreenCapturer.instance;
  Uint8List? lastScreenshot;
  final Function(String) onStatusUpdate;
  final Function() onScreenshotTaken;
  final Future<String> Function(String question)? onUserPrompt;

  AutomationService({
    required this.onStatusUpdate,
    required this.onScreenshotTaken,
    this.onUserPrompt,
  });

  // Capture screenshot function
  Future<Map<String, dynamic>> captureScreenshot() async {
    try {
      final capturedImage = await _screenCapturer.capture(
        mode: CaptureMode.screen,
      );
      if (capturedImage != null) {
        lastScreenshot = capturedImage.imageBytes;
        lastScreenshot = await resizeImage(lastScreenshot!);
        onScreenshotTaken();
        return {
          'success': true,
          'message': 'Screenshot captured successfully',
          'hasImage': true,
        };
      }
      return {
        'success': false,
        'message': 'Failed to capture screenshot',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error capturing screenshot: $e',
      };
    }
  }

  Future<Uint8List?> resizeImage(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        return null;
      }

      // Determine new dimensions while preserving aspect ratio
      final resizedImage = img.copyResize(
        image,
        width: (image.width / 3).toInt(),
        height: (image.height / 3).toInt(),
      );

      // Encode the resized image to a PNG byte array
      return img.encodePng(resizedImage);
    } catch (e) {
      print('Error creating thumbnail: $e');
      return null;
    }
  }

  // Detect element position function
  Future<Map<String, dynamic>> detectElementPosition({
    required String elementDescription,
  }) async {
    try {
      if (lastScreenshot == null) {
        return {
          'success': false,
          'message':
              'No screenshot available. Please capture a screenshot first.',
        };
      }

      onStatusUpdate('Detecting element: $elementDescription');

      final result = await VisionService.detectElementPosition(
        lastScreenshot!,
        elementDescription,
      );

      if (result.status == 'success') {
        return {
          'success': true,
          'message':
              'Element detected at coordinates (${result.x}, ${result.y})',
          'x': result.x,
          'y': result.y,
          'confidence': result.confidence,
          'element_description': elementDescription,
        };
      } else {
        return {
          'success': false,
          'message': result.errorMessage ?? 'Failed to detect element',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error detecting element position: $e',
      };
    }
  }

  // Move mouse function
  Map<String, dynamic> moveMouse({
    required int x,
    required int y,
  }) {
    print("Moving mouse to ($x, $y)");
    try {
      BixatKeyMouse.moveMouse(
        x: x,
        y: y,
      );
      return {
        'success': true,
        'message': 'Mouse moved to ($x, $y)',
        'position': {'x': x, 'y': y},
      };
    } catch (e) {
      print(e);
      return {
        'success': false,
        'message': 'Error moving mouse: $e',
      };
    }
  }

  // Click mouse function
  Map<String, dynamic> clickMouse({
    String button = 'left',
    String action = 'click',
  }) {
    try {
      final mouseButton = switch (button.toLowerCase()) {
        'left' => MouseButton.left,
        'middle' => MouseButton.middle,
        _ => MouseButton.right,
      };

      BixatKeyMouse.pressMouseButton(
          button: mouseButton, direction: Direction.click);

      return {
        'success': true,
        'message': 'Mouse $button button $action successful',
        'button': button,
        'action': action,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error clicking mouse: $e',
      };
    }
  }

  // Type text function
  Map<String, dynamic> typeText({required String text}) {
    try {
      BixatKeyMouse.enterText(text: text);
      return {
        'success': true,
        'message': 'Text typed successfully',
        'text': text,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error typing text: $e',
      };
    }
  }

  // Press key function
  Future<Map<String, dynamic>> pressKeys({required List keys}) async {
    try {
      final unvKeys = <UniversalKey>[];
      for (var key in keys) {
        final unvKey = UniversalKey.values.firstWhere((e) => e.name == key);
        unvKeys.add(unvKey);
      }
      BixatKeyMouse.simulateKeyCombination(keys: unvKeys);
      return {
        'success': true,
        'message': 'Keys pressed: $keys',
        'keys': keys,
      };
    } catch (e) {
      print(e);
      return {
        'success': false,
        'message': 'Error pressing key: $e',
      };
    }
  }

  // Wait function
  Future<Map<String, dynamic>> wait({required double seconds}) async {
    try {
      await Future.delayed(Duration(milliseconds: (seconds * 1000).toInt()));
      return {
        'success': true,
        'message': 'Waited for $seconds seconds',
        'duration': seconds,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error waiting: $e',
      };
    }
  }

  // Get keyboard shortcuts function
  Future<Map<String, dynamic>> getShortcuts({required String query}) async {
    try {
      onStatusUpdate('Fetching shortcuts for: $query');
      final result = await ShortcutsService.getShortcuts(query: query);

      if (result['success'] == true) {
        final shortcuts = result['shortcuts'] as List;
        final formattedShortcuts = shortcuts.map((s) {
          return '${s['description']}: ${s['keys']}${s['example'] != null ? ' (${s['example']})' : ''}';
        }).join('\n');

        return {
          'success': true,
          'message': 'Found ${shortcuts.length} shortcuts',
          'shortcuts': shortcuts,
          'formatted': formattedShortcuts,
          'provider': result['provider'],
        };
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting shortcuts: $e',
        'shortcuts': [],
      };
    }
  }

  /// Asks the user a question and waits for their response
  /// This pauses automation until the user provides input
  Future<Map<String, dynamic>> askUser({required String question}) async {
    try {
      onStatusUpdate('Waiting for user input: $question');

      if (onUserPrompt == null) {
        return {
          'success': false,
          'message': 'User interaction not available',
          'user_response': null,
        };
      }

      // Wait for user response
      final userResponse = await onUserPrompt!(question);

      return {
        'success': true,
        'message': 'User responded',
        'user_response': userResponse,
        'question': question,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error asking user: $e',
        'user_response': null,
      };
    }
  }
}
