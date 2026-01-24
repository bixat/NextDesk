import 'dart:convert';
import 'dart:io';
import 'package:bixat_key_mouse/bixat_key_mouse.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'config_service.dart';

/// Service for fetching keyboard shortcuts using AI
class ShortcutsService {
  static const String _openRouterApiUrl =
      "https://openrouter.ai/api/v1/chat/completions";

  /// Fetches keyboard shortcuts for a specific app or system task
  /// Uses OpenRouter.
  static Future<Map<String, dynamic>> getShortcuts({
    required String query,
    ConfigService? config,
  }) async {
    try {
      final openRouterKey =
          config?.openRouterApiKey ?? AppConfig.openRouterApiKey;
      final os = Platform.operatingSystem;

      final systemPrompt =
          '''You are a keyboard shortcuts expert. Provide accurate keyboard shortcuts for ${os.toUpperCase()} operating system.

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

      return await _fetchWithOpenRouter(
          systemPrompt, userPrompt, openRouterKey);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching shortcuts: $e',
        'shortcuts': [],
      };
    }
  }

  static Future<Map<String, dynamic>> _fetchWithOpenRouter(
      String systemPrompt, String userPrompt, String apiKey) async {
    try {
      final requestBody = {
        "model": "google/gemini-3-flash-preview",
        "messages": [
          {"role": "system", "content": systemPrompt},
          {"role": "user", "content": userPrompt}
        ],
        "temperature": 0.3,
        "response_format": {"type": "json_object"},
      };

      final response = await http.post(
        Uri.parse(_openRouterApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://bixat.dev/products/nextdesk',
          'X-Title': 'NextDesk',
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
            'provider': 'openrouter',
          };
        }
      }

      return {
        'success': false,
        'message': 'Failed to fetch shortcuts from OpenRouter',
        'shortcuts': [],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'OpenRouter error: $e',
        'shortcuts': [],
      };
    }
  }

  static String _getValidKeyNames() {
    return UniversalKey.values.map((e) => e.name).join(', ');
  }
}
