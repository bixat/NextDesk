import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/detection_result.dart';

/// Element Position Detection Service using Gemini Vision API
class VisionService {
  static const String _apiKey = "AIzaSyCqF8yEv4MwA_rp6vzdUckXMt0qGHRg6X4";
  static const String _apiUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

  /// Detects the pixel coordinates of UI elements in a screenshot using Gemini Vision API.
  static Future<DetectionResult> detectElementPosition(
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
        Uri.parse('$_apiUrl?key=$_apiKey'),
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

