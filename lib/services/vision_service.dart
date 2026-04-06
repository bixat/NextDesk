import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/detection_result.dart';
import '../config/app_config.dart';
import 'config_service.dart';
import 'holo3_vision_service.dart';

/// Element Position Detection Service using Vision API
/// Supports both OpenRouter and HCompany Holo3 backends
class VisionService {
  /// Detects the pixel coordinates of UI elements in a screenshot.
  /// Automatically selects the appropriate backend based on configured vision model.
  static Future<DetectionResult> detectElementPosition(Uint8List imageBytes,
      String elementDescription, ConfigService? config) async {
    final visionModel = config?.visionModel ?? AppConfig.visionModel;

    // Use HCompany Holo3 directly for holo3 models
    if (visionModel.contains('hcompany') || visionModel.contains('holo3')) {
      return Holo3VisionService.detectElementPosition(
          imageBytes, elementDescription, config);
    }

    // Fallback to OpenRouter for other models
    final openRouterKey =
        config?.openRouterApiKey ?? AppConfig.openRouterApiKey;
    return _detectWithOpenRouter(
        imageBytes, elementDescription, openRouterKey, visionModel);
  }

  /// Detects the pixel coordinates of UI elements using OpenRouter Vision API.
  static Future<DetectionResult> _detectWithOpenRouter(
      Uint8List imageBytes, String elementDescription, String apiKey, String visionModel) async {
    try {
      final base64Image = base64Encode(imageBytes);

      // Prepare the prompt
      final prompt = '''Analyze the provided screenshot.
Find the center pixel coordinates of the element described as: "$elementDescription".

Provide a brief description of what you see in the screenshot.
If the exact element is not found but a similar alternative exists, explicitly mention both in the description.

Return your response in this exact JSON format:
{
  "x": <integer>,
  "y": <integer>,
  "confidence": <float between 0.0 and 1.0>,
  "screenshot_description": <string>,
  "image_size": {
    "width": <integer>,
    "height": <integer>
  }
}''';

      final requestBody = {
        "model": visionModel,
        "messages": [
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": prompt,
              },
              {
                "type": "image_url",
                "image_url": {
                  "url": "data:image/png;base64,$base64Image",
                }
              }
            ]
          }
        ]
      };

      // Make API request
      final response = await http.post(
        Uri.parse("https://openrouter.ai/api/v1/chat/completions"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://bixat.dev/products/nextdesk',
          'X-Title': 'NextDesk',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        return DetectionResult(
          status: "error",
          errorMessage:
              "OpenRouter API request failed with status: ${response.statusCode}\nResponse: ${response.body}",
          x: null,
          y: null,
          confidence: 0.0,
          imageSize: null,
        );
      }

      // Parse response
      final responseData = jsonDecode(response.body);
      final choices = responseData['choices'] as List?;

      if (choices == null || choices.isEmpty) {
        return DetectionResult(
          status: "error",
          errorMessage: "No response from OpenRouter API",
          x: null,
          y: null,
          confidence: 0.0,
          imageSize: null,
        );
      }

      final message = choices[0]['message'];
      final content = message['content'] as String;

      // Parse JSON response
      try {
        final parsedResult = jsonDecode(content) as Map<String, dynamic>;
        final xCoord = parsedResult['x'];
        final yCoord = parsedResult['y'];
        final confidence = parsedResult['confidence'];
        final screenshotDesc =
            parsedResult['screenshot_description'] as String?;
        final imageSize = parsedResult['image_size'];

        if (xCoord != null && yCoord != null) {
          return DetectionResult(
            status: "success",
            x: xCoord is int ? xCoord : int.parse(xCoord.toString()),
            y: yCoord is int ? yCoord : int.parse(yCoord.toString()),
            screenshotDescription: screenshotDesc ?? elementDescription,
            confidence: confidence is double
                ? confidence
                : (confidence != null
                    ? double.parse(confidence.toString())
                    : 0.9),
            imageSize: imageSize != null
                ? {
                    'width': imageSize['width'] as int,
                    'height': imageSize['height'] as int,
                  }
                : null,
          );
        } else {
          return DetectionResult(
            status: "error",
            errorMessage:
                "Element not found by OpenRouter Vision API or coordinates are null",
            x: null,
            y: null,
            screenshotDescription: screenshotDesc,
            confidence: 0.0,
            imageSize: imageSize != null
                ? {
                    'width': imageSize['width'] as int,
                    'height': imageSize['height'] as int,
                  }
                : null,
          );
        }
      } catch (jsonError) {
        return DetectionResult(
          status: "error",
          errorMessage: "OpenRouter API returned invalid JSON: $content",
          x: null,
          y: null,
          confidence: 0.0,
        );
      }
    } catch (e) {
      return DetectionResult(
        status: "error",
        errorMessage:
            "Failed to detect element position using OpenRouter: ${e.toString()}",
        x: null,
        y: null,
        confidence: 0.0,
      );
    }
  }
}
