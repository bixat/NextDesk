import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/detection_result.dart';
import '../config/app_config.dart';

/// Element Position Detection Service using Gemini or Qwen Vision API
class VisionService {
  static const String _geminiApiUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
  static const String _qwenApiUrl =
      "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions";

  /// Detects the pixel coordinates of UI elements in a screenshot.
  /// Uses the provider specified in AppConfig.visionProvider ('gemini' or 'qwen').
  static Future<DetectionResult> detectElementPosition(
      Uint8List imageBytes, String elementDescription) async {
    if (AppConfig.visionProvider == 'qwen') {
      return _detectWithQwen(imageBytes, elementDescription);
    } else {
      return _detectWithGemini(imageBytes, elementDescription);
    }
  }

  /// Detects the pixel coordinates of UI elements using Qwen Vision API.
  static Future<DetectionResult> _detectWithQwen(
      Uint8List imageBytes, String elementDescription) async {
    try {
      final base64Image = base64Encode(imageBytes);

      // System instruction for Qwen with strict JSON schema
      final systemInstruction =
          '''You are an advanced AI assistant capable of analyzing images and extracting information based on user queries.
Your task is to identify and provide the coordinates of specific UI elements within a given screenshot.

CRITICAL: You MUST return ONLY valid JSON in this EXACT format:
{
  "x": <integer>,
  "y": <integer>,
  "confidence": <float between 0.0 and 1.0>,
  "screenshot_description": <string>,
  "image_size": {
    "width": <integer>,
    "height": <integer>
  }
}

Rules:
- x and y are integers representing pixel coordinates of the element's center
- If element not found, set x and y to null
- confidence is a float between 0.0 and 1.0
- screenshot_description: Brief description of what you see in the screenshot
  * If the requested element is found, describe its context
  * If the requested element is NOT found but a similar element exists, explicitly mention both (e.g., "Screenshot shows App Store page with 'Update' button instead of requested 'Get' button, indicating app is already installed")
  * If nothing similar exists, describe what is visible
- image_size must contain the actual image dimensions
- Do NOT include any text outside the JSON object
- Do NOT use arrays or extra fields''';

      // User prompt
      final prompt =
          'Locate the center pixel coordinates of: $elementDescription\n\nProvide a description of what you see, especially if the exact element is not found but a similar alternative exists.';

      // Calculate min and max pixels based on typical screen resolution
      final minPixels = (1920 / 2) * 28 * 28;
      final maxPixels = (1920 * 2) * 28 * 28;

      // Prepare API request for Qwen (OpenAI-compatible format)
      final requestBody = {
        "model": "qwen2.5-vl-72b-instruct",
        "messages": [
          {
            "role": "system",
            "content": [
              {"type": "text", "text": systemInstruction}
            ]
          },
          {
            "role": "user",
            "content": [
              {
                "type": "image_url",
                "min_pixels": minPixels.toInt(),
                "max_pixels": maxPixels.toInt(),
                "image_url": {"url": "data:image/png;base64,$base64Image"}
              },
              {"type": "text", "text": prompt}
            ]
          }
        ],
        "response_format": {
          "type": "json_schema",
          "json_schema": {
            "name": "element_coordinates",
            "strict": true,
            "schema": {
              "type": "object",
              "properties": {
                "x": {
                  "type": ["integer", "null"],
                  "description": "X coordinate of element center in pixels"
                },
                "y": {
                  "type": ["integer", "null"],
                  "description": "Y coordinate of element center in pixels"
                },
                "confidence": {
                  "type": "number",
                  "description": "Confidence score between 0.0 and 1.0",
                  "minimum": 0.0,
                  "maximum": 1.0
                },
                "screenshot_description": {
                  "type": "string",
                  "description":
                      "Brief description of what is visible in the screenshot, especially mentioning if requested element was found or if similar alternative exists"
                },
                "image_size": {
                  "type": "object",
                  "properties": {
                    "width": {"type": "integer"},
                    "height": {"type": "integer"}
                  },
                  "required": ["width", "height"],
                  "additionalProperties": false
                }
              },
              "required": [
                "x",
                "y",
                "confidence",
                "screenshot_description",
                "image_size"
              ],
              "additionalProperties": false
            }
          }
        }
      };

      // Make API request
      final response = await http.post(
        Uri.parse(_qwenApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.qwenApiKey}',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        return DetectionResult(
          status: "error",
          errorMessage:
              "Qwen API request failed with status: ${response.statusCode}\nResponse: ${response.body}",
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
          errorMessage: "No response from Qwen API",
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
                "Element not found by Qwen Vision API or coordinates are null",
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
          errorMessage: "Qwen API returned invalid JSON: $content",
          x: null,
          y: null,
          confidence: 0.0,
        );
      }
    } catch (e) {
      return DetectionResult(
        status: "error",
        errorMessage:
            "Failed to detect element position using Qwen: ${e.toString()}",
        x: null,
        y: null,
        confidence: 0.0,
      );
    }
  }

  /// Detects the pixel coordinates of UI elements using Gemini Vision API.
  static Future<DetectionResult> _detectWithGemini(
      Uint8List imageBytes, String elementDescription) async {
    try {
      final base64Image = base64Encode(imageBytes);

      // Prepare the prompt
      final prompt = '''
Analyze the provided screenshot.
Find the center pixel coordinates of the element described as: "$elementDescription".

Provide a brief description of what you see in the screenshot.
If the exact element is not found but a similar alternative exists, explicitly mention both in the description.
For example: "Screenshot shows App Store page with 'Update' button instead of requested 'Get' button, indicating app is already installed"
''';

      // Prepare API request with response schema
      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inline_data": {"mime_type": "image/png", "data": base64Image}
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.5,
          "responseMimeType": "application/json",
          "responseSchema": {
            "type": "object",
            "properties": {
              "x": {
                "type": "integer",
                "description": "X coordinate of element center in pixels"
              },
              "y": {
                "type": "integer",
                "description": "Y coordinate of element center in pixels"
              },
              "confidence": {
                "type": "number",
                "description": "Confidence score between 0.0 and 1.0"
              },
              "screenshot_description": {
                "type": "string",
                "description":
                    "Brief description of what is visible in the screenshot, especially mentioning if requested element was found or if similar alternative exists"
              },
              "image_size": {
                "type": "object",
                "properties": {
                  "width": {"type": "integer"},
                  "height": {"type": "integer"}
                },
                "required": ["width", "height"]
              }
            },
            "required": [
              "x",
              "y",
              "confidence",
              "screenshot_description",
              "image_size"
            ]
          }
        },
        "safetySettings": [
          {
            "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
            "threshold": "BLOCK_ONLY_HIGH"
          }
        ],
        "systemInstruction": {
          "parts": [
            {
              "text":
                  "You are an expert at analyzing UI elements in screenshots. Identify the exact center pixel coordinates of UI elements. Provide clear descriptions of what you see, especially when the requested element differs from what's actually present. Be precise with element identification."
            }
          ]
        }
      };

      // Make API request
      final response = await http.post(
        Uri.parse('$_geminiApiUrl?key=${AppConfig.geminiApiKey}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        return DetectionResult(
          status: "error",
          errorMessage:
              "API request failed with status: ${response.statusCode}",
          x: null,
          y: null,
          confidence: 0.0,
          imageSize: null,
        );
      }

      // Parse response
      final responseData = jsonDecode(response.body);
      final candidates = responseData['candidates'] as List?;

      if (candidates == null || candidates.isEmpty) {
        return DetectionResult(
          status: "error",
          errorMessage: "No response from Gemini API",
          x: null,
          y: null,
          confidence: 0.0,
          imageSize: null,
        );
      }

      final content = candidates[0]['content'];
      final parts = content['parts'] as List;
      final text = parts[0]['text'] as String;

      // Parse JSON response
      try {
        // Clean the response text - remove markdown formatting if present
        String cleanText = text.trim();
        if (cleanText.startsWith('```json')) {
          cleanText = cleanText
              .replaceFirst('```json', '')
              .replaceFirst('```', '')
              .trim();
        } else if (cleanText.startsWith('```')) {
          cleanText =
              cleanText.replaceFirst('```', '').replaceFirst('```', '').trim();
        }

        final parsedResult = jsonDecode(cleanText) as Map<String, dynamic>;
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
                "Element not found by Gemini Vision API or coordinates are null",
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
          errorMessage: "Gemini API returned invalid JSON: $text",
          x: null,
          y: null,
          confidence: 0.0,
        );
      }
    } catch (e) {
      return DetectionResult(
        status: "error",
        errorMessage:
            "Failed to detect element position using Gemini: ${e.toString()}",
        x: null,
        y: null,
        confidence: 0.0,
      );
    }
  }
}
