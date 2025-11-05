import 'dart:convert';
import 'dart:io';
import 'package:bixat_key_mouse/bixat_key_mouse.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Service for fetching keyboard shortcuts using AI
class ShortcutsService {
  static const String _geminiApiUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
  static const String _qwenApiUrl =
      "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions";

  /// Fetches keyboard shortcuts for a specific app or system task
  /// Uses the provider specified in AppConfig.shortcutsProvider ('gemini' or 'qwen')
  static Future<Map<String, dynamic>> getShortcuts({
    required String query,
  }) async {
    try {
      final provider = AppConfig.shortcutsProvider;
      final os = Platform.operatingSystem;
      
      final systemPrompt = '''You are a keyboard shortcuts expert. Provide accurate keyboard shortcuts for ${os.toUpperCase()} operating system.

CRITICAL RULES:
1. Return ONLY valid shortcuts that actually exist
2. Use the exact key names from this list: ${_getValidKeyNames()}
3. Format shortcuts as arrays: ["leftCommand", "space"] for Cmd+Space
4. Return JSON format ONLY
5. Be concise - maximum 10 most useful shortcuts

Output format:
{
  "shortcuts": [
    {
      "description": "Brief description of what it does",
      "keys": ["key1", "key2"],
      "example": "Optional usage example"
    }
  ]
}''';

      final userPrompt = '''Find keyboard shortcuts for: $query

Operating System: $os
Provide the most commonly used and reliable shortcuts.''';

      if (provider == 'qwen') {
        return await _fetchWithQwen(systemPrompt, userPrompt);
      } else {
        return await _fetchWithGemini(systemPrompt, userPrompt);
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching shortcuts: $e',
        'shortcuts': [],
      };
    }
  }

  static Future<Map<String, dynamic>> _fetchWithGemini(
      String systemPrompt, String userPrompt) async {
    try {
      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": userPrompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.3,
          "responseMimeType": "application/json",
        },
        "systemInstruction": {
          "parts": [
            {"text": systemPrompt}
          ]
        }
      };

      final response = await http.post(
        Uri.parse('$_geminiApiUrl?key=${AppConfig.geminiApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (content != null) {
          final result = jsonDecode(content);
          return {
            'success': true,
            'shortcuts': result['shortcuts'] ?? [],
            'provider': 'gemini',
          };
        }
      }

      return {
        'success': false,
        'message': 'Failed to fetch shortcuts from Gemini',
        'shortcuts': [],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gemini error: $e',
        'shortcuts': [],
      };
    }
  }

  static Future<Map<String, dynamic>> _fetchWithQwen(
      String systemPrompt, String userPrompt) async {
    try {
      final requestBody = {
        "model": "qwen-vl-max-latest",
        "messages": [
          {"role": "system", "content": systemPrompt},
          {"role": "user", "content": userPrompt}
        ],
        "temperature": 0.3,
        "response_format": {"type": "json_object"},
      };

      final response = await http.post(
        Uri.parse(_qwenApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.qwenApiKey}',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        
        if (content != null) {
          final result = jsonDecode(content);
          return {
            'success': true,
            'shortcuts': result['shortcuts'] ?? [],
            'provider': 'qwen',
          };
        }
      }

      return {
        'success': false,
        'message': 'Failed to fetch shortcuts from Qwen',
        'shortcuts': [],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Qwen error: $e',
        'shortcuts': [],
      };
    }
  }

  static String _getValidKeyNames() {
    return UniversalKey.values.map((e) => e.name).join(', ');
  }
}
