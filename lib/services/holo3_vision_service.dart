import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/detection_result.dart';
import '../config/app_config.dart';
import 'config_service.dart';

/// Element Position Detection Service using HCompany Holo3 API
class Holo3VisionService {
  static const String _hCompanyApiUrl =
      "https://api.hcompany.ai/v1/chat/completions";

  /// Detects the pixel coordinates of UI elements in a screenshot.
  /// Uses HCompany Holo3 API directly.
  static Future<DetectionResult> detectElementPosition(
      Uint8List imageBytes, String elementDescription, ConfigService? config) async {
    final hCompanyKey = config?.hCompanyApiKey ?? AppConfig.hCompanyApiKey;

    if (hCompanyKey.isEmpty) {
      return DetectionResult(
        status: "error",
        errorMessage:
            "HCompany API key is not configured. Please set HCOMPANY_API_KEY environment variable or configure in settings.",
        x: null,
        y: null,
        confidence: 0.0,
        imageSize: null,
      );
    }

    return _detectWithHolo3(imageBytes, elementDescription, hCompanyKey);
  }

  /// Detects the pixel coordinates of UI elements using HCompany Holo3 API.
  static Future<DetectionResult> _detectWithHolo3(
      Uint8List imageBytes, String elementDescription, String apiKey) async {
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
        "model": "holo3-35b-a3b",
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

      // Make API request to HCompany
      final response = await http.post(
        Uri.parse(_hCompanyApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        return DetectionResult(
          status: "error",
          errorMessage:
              "HCompany API request failed with status: ${response.statusCode}\nResponse: ${response.body}",
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
          errorMessage: "No response from HCompany Holo3 API",
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
        final screenshotDesc = parsedResult['screenshot_description'] as String?;
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
                "Element not found by Holo3 API or coordinates are null",
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
          errorMessage: "Holo3 API returned invalid JSON: $content",
          x: null,
          y: null,
          confidence: 0.0,
        );
      }
    } catch (e) {
      return DetectionResult(
        status: "error",
        errorMessage: "Failed to detect element position using Holo3: ${e.toString()}",
        x: null,
        y: null,
        confidence: 0.0,
      );
    }
  }
}
