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

      // System instruction for Qwen
      final systemInstruction =
          '''You are an advanced AI assistant capable of analyzing images and extracting information based on user queries.
Your task is to identify and provide the coordinates of specific UI elements within a given screenshot,
You should be able to interpret descriptions of UI elements and map them accurately to their positions in the image.

Focus on pixel-perfect accuracy and reliable element detection.
Return the result as a JSON object with 'x', 'y' (integers), 'confidence' (float), and 'image_size' (object with 'width', 'height').
If the element is not found, return x and y as null.''';

      // User prompt
      final prompt =
          'Locate the center of $elementDescription, output its (x,y) coordinates using JSON format';

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
        "response_format": {"type": "json_object"}
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
        final imageSize = parsedResult['image_size'];

        if (xCoord != null && yCoord != null) {
          return DetectionResult(
            status: "success",
            x: xCoord is int ? xCoord : int.parse(xCoord.toString()),
            y: yCoord is int ? yCoord : int.parse(yCoord.toString()),
            screenshotDescription: elementDescription,
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
Find the center coordinates of the element described as: "$elementDescription".
Return your answer ONLY as a JSON object with 'x' and 'y' keys.
For example: {"x": 123, "y": 456, "image_description": "Short image description"}
''';

      // Prepare API request
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
                  "You are an expert at analyzing UI elements in screenshots. Return coordinates as JSON only. Be precise with element identification."
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

        if (xCoord != null && yCoord != null) {
          return DetectionResult(
            status: "success",
            x: xCoord is int ? xCoord : int.parse(xCoord.toString()),
            y: yCoord is int ? yCoord : int.parse(yCoord.toString()),
            screenshotDescription: elementDescription,
            confidence: 0.9, // Default confidence
          );
        } else {
          return DetectionResult(
            status: "error",
            errorMessage:
                "Element not found by Gemini Vision API or coordinates are null",
            x: null,
            y: null,
            confidence: 0.0,
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
