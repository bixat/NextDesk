import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:bixat_key_mouse/bixat_key_mouse.dart';
import '../config/app_config.dart';
import 'config_service.dart';

class OpenRouterService {
  static const String _baseUrl =
      "https://openrouter.ai/api/v1/chat/completions";
  final String apiKey;
  final String model;

  // Default headers
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer':
            'https://github.com/bixat-dev/desktop-agent', // Required by OpenRouter
        'X-Title': 'NextDesk', // Optional
      };

  OpenRouterService({required this.apiKey, required this.model});

  static OpenRouterService? initialize(ConfigService? config) {
    final apiKey = config?.openRouterApiKey ?? AppConfig.openRouterApiKey;
    if (apiKey.isEmpty) return null;

    return OpenRouterService(
      apiKey: apiKey,
      model: 'google/gemini-3-flash-preview',
    );
  }

  OpenRouterChatSession startChat({List<Map<String, dynamic>>? history}) {
    return OpenRouterChatSession(service: this, history: history ?? []);
  }

  static final List<Map<String, dynamic>> tools = [
    {
      "type": "function",
      "function": {
        "name": "captureScreenshot",
        "description": "Captures a screenshot of the current screen",
        "parameters": {
          "type": "object",
          "properties": {},
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "detectElementPosition",
        "description":
            "Detects the pixel coordinates of a UI element in the current screenshot using AI vision",
        "parameters": {
          "type": "object",
          "properties": {
            "elementDescription": {
              "type": "string",
              "description":
                  "Natural language description of the UI element to locate (e.g., \"Submit button\", \"Username text field\", \"Close icon\")"
            }
          },
          "required": ["elementDescription"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "moveMouse",
        "description": "Moves the mouse cursor to specified coordinates",
        "parameters": {
          "type": "object",
          "properties": {
            "x": {"type": "integer", "description": "X coordinate on screen"},
            "y": {"type": "integer", "description": "Y coordinate on screen"}
          },
          "required": ["x", "y"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "clickMouse",
        "description": "Clicks a mouse button at current position",
        "parameters": {
          "type": "object",
          "properties": {
            "button": {
              "type": "string",
              "description": "Mouse button to click: left, right, or middle",
              "enum": ["left", "right", "middle"]
            },
            "action": {
              "type": "string",
              "description": "Type of action: click, press, or release",
              "enum": ["click", "press", "release"]
            }
          }
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "typeText",
        "description": "Types text using the keyboard",
        "parameters": {
          "type": "object",
          "properties": {
            "text": {"type": "string", "description": "Text to type"}
          },
          "required": ["text"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "pressKeys",
        "description": "Presses a keyboard keys",
        "parameters": {
          "type": "object",
          "properties": {
            "keys": {
              "type": "array",
              "description": "Key to press [cmd, space]",
              "items": {
                "type": "string",
                "enum": UniversalKey.values.map((e) => e.name).toList()
              }
            }
          },
          "required": ["keys"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "wait",
        "description": "Waits for a specified number of seconds",
        "parameters": {
          "type": "object",
          "properties": {
            "seconds": {
              "type": "number",
              "description": "Number of seconds to wait"
            }
          },
          "required": ["seconds"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "getShortcuts",
        "description":
            "Fetches keyboard shortcuts for a specific app or system task using AI. Use this to discover shortcuts instead of using vision/mouse.",
        "parameters": {
          "type": "object",
          "properties": {
            "query": {
              "type": "string",
              "description":
                  "Description of the app or task to get shortcuts for (e.g., \"Chrome browser\", \"VS Code\", \"macOS window management\", \"text editing\")"
            }
          },
          "required": ["query"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "askUser",
        "description": "Asks the user a question and waits for their response.",
        "parameters": {
          "type": "object",
          "properties": {
            "question": {
              "type": "string",
              "description": "The question to ask the user."
            }
          },
          "required": ["question"]
        }
      }
    }
  ];

  static String getReActSystemPrompt(String userInput) {
    final os = Platform.operatingSystem;
    // ... Copy prompt from GeminiService ...
    return '''
You are an AI automation assistant operating under the ReAct (Reasoning + Acting) framework. Your primary goal is to complete the given task with maximum efficiency and reliability using KEYBOARD SHORTCUTS ONLY.

**CORE PRINCIPLES:**
1.  **KEYBOARD-FIRST AUTOMATION:** You MUST ALWAYS try keyboard shortcuts (`pressKeys`) FIRST for ALL tasks. Keyboard shortcuts are 100x faster and more reliable than vision.
2.  **Use getShortcuts Tool:** When you don't know the keyboard shortcut for a task, call `getShortcuts(query)` to discover the correct shortcuts.
3.  **Vision as FALLBACK ONLY:** Use vision (`detectElementPosition`, `moveMouse`, `clickMouse`) ONLY when:
    - Keyboard shortcuts have been tried and FAILED
    - The task requires clicking on custom UI elements that have no keyboard shortcut
    - You've exhausted all keyboard alternatives
4.  **Action-Oriented Steps:** Break the task down into discrete actions. Prefer keyboard actions over mouse actions.
5.  **Smart Verification:** Use `captureScreenshot` to verify success after actions. If keyboard approach fails, acknowledge it and switch to vision fallback.

**COMMON ${os.toUpperCase()} KEYBOARD SHORTCUTS:**
${_getCommonShortcuts(os)}

**STRUCTURED EXECUTION FORMAT:**
For every step, follow this format:

THOUGHT: [Your reasoning about the current step and what you plan to do next. State which keyboard shortcut or function you'll use.]

Then immediately call the appropriate function using function calling.

When the task is complete, state "TASK COMPLETE" in your thought and take a final screenshot.

**AVAILABLE FUNCTIONS (in priority order):**

**PRIMARY TOOLS (Use First):**
1. `getShortcuts(query)`: Discover keyboard shortcuts for an app or task. Returns shortcuts with descriptions.
2. `pressKeys(keys)`: **YOUR PRIMARY TOOL** - Presses keyboard key combinations (e.g., ["leftCommand", "space"], ["leftCommand", "t"]).
3. `typeText(text)`: Types text using the keyboard.
4. `wait(seconds)`: Waits for a specified time. Use short waits (0.3-1s) between actions.
5. `captureScreenshot()`: Takes a screenshot for verification.

**USER INTERACTION TOOL:**
6. `askUser(question)`: **IMPORTANT** - Asks the user a question and waits for their response. Use this when:
   - The actual UI state differs from expectations (e.g., looking for "Get" button but found "Update" button)
   - You need clarification on how to proceed
   - The screenshot_description from vision detection indicates a mismatch
   - Example: `askUser("WhatsApp is already installed. I see an 'Update' button instead of 'Get'. Would you like me to update it or cancel?")`

**FALLBACK TOOLS (Use ONLY if keyboard approach fails):**
7. `detectElementPosition(elementDescription)`: Finds a UI element using vision. Returns coordinates AND screenshot_description. Check the description for mismatches!
8. `moveMouse(x, y)`: Moves mouse to coordinates (from detectElementPosition).
9. `clickMouse(button, action)`: Clicks at current mouse position.

**CRITICAL RULES:**
1.  **Keyboard-First Strategy:** For EVERY task, think "What keyboard shortcut can do this?" before considering any other method.
2.  **Discover Shortcuts:** If you don't know the shortcut, call `getShortcuts(query)` to learn it. Don't guess.
3.  **Try Before Fallback:** Always attempt the keyboard approach first. Only switch to vision if:
    - You get an error/failure after trying keyboard shortcuts
    - You explicitly verify the keyboard action didn't work (via screenshot)
    - The UI element has no keyboard shortcut (e.g., custom buttons in web apps)
4.  **Check Vision Results:** When using `detectElementPosition`, ALWAYS check the `screenshot_description` field in the result. If it indicates a mismatch (e.g., found different button than requested), call `askUser()` to confirm how to proceed.
5.  **Ask Before Acting on Mismatches:** If the screenshot_description shows the UI differs from expectations, PAUSE and ask the user before clicking. Example: If looking for "Get" but found "Update", ask user first.
6.  **Acknowledge Failures:** If keyboard approach fails, state in THOUGHT: "Keyboard approach failed, switching to vision fallback" before using detectElementPosition.
7.  **Task Completion:** When the final goal is achieved, state "TASK COMPLETE" in your THOUGHT and take ONE final screenshot.

**Current Task: "$userInput"**
**Operating System: $os**

Begin with your first THOUGHT:
''';
  }

  static String _getCommonShortcuts(String os) {
    if (os == 'macos') {
      return '''
**System Navigation:**
- Open Spotlight: ["leftCommand", "space"]
- Switch apps: ["leftCommand", "tab"]
- Switch windows (same app): ["leftCommand", "grave"]
- Close window: ["leftCommand", "w"]
- Quit app: ["leftCommand", "q"]
- New window: ["leftCommand", "n"]
- Minimize window: ["leftCommand", "m"]
- Hide app: ["leftCommand", "h"]
- Show desktop: ["f11"]
- Mission Control: ["leftControl", "arrowUp"]
- App Exposé: ["leftControl", "arrowDown"]

**Text Editing:**
- Copy: ["leftCommand", "c"]
- Paste: ["leftCommand", "v"]
- Cut: ["leftCommand", "x"]
- Undo: ["leftCommand", "z"]
- Redo: ["leftCommand", "leftShift", "z"]
- Select all: ["leftCommand", "a"]
- Find: ["leftCommand", "f"]
- Save: ["leftCommand", "s"]
- Delete word: ["leftAlt", "delete"]
- Move to line start: ["leftCommand", "arrowLeft"]
- Move to line end: ["leftCommand", "arrowRight"]

**Browser (Chrome/Safari):**
- New tab: ["leftCommand", "t"]
- Close tab: ["leftCommand", "w"]
- Reopen closed tab: ["leftCommand", "leftShift", "t"]
- Next tab: ["leftCommand", "leftAlt", "arrowRight"]
- Previous tab: ["leftCommand", "leftAlt", "arrowLeft"]
- Address bar: ["leftCommand", "l"]
- Reload: ["leftCommand", "r"]
- New window: ["leftCommand", "n"]
- New private window: ["leftCommand", "leftShift", "n"]
- Downloads: ["leftCommand", "leftShift", "j"]
- Bookmarks: ["leftCommand", "leftShift", "b"]

**VS Code:**
- Command palette: ["leftCommand", "leftShift", "p"]
- Quick open: ["leftCommand", "p"]
- Toggle terminal: ["leftCommand", "grave"]
- New file: ["leftCommand", "n"]
- Save: ["leftCommand", "s"]
- Find: ["leftCommand", "f"]
- Replace: ["leftCommand", "leftAlt", "f"]
- Go to line: ["leftControl", "g"]
- Comment line: ["leftCommand", "slash"]''';
    } else if (os == 'windows' || os == 'linux') {
      return '''
**System Navigation:**
- Open search: ["leftCommand", "s"] (Windows) or ["leftAlt", "f2"] (Linux)
- Switch apps: ["leftAlt", "tab"]
- Close window: ["leftAlt", "f4"]
- New window: ["leftControl", "n"]
- Minimize window: ["leftCommand", "arrowDown"]

**Text Editing:**
- Copy: ["leftControl", "c"]
- Paste: ["leftControl", "v"]
- Cut: ["leftControl", "x"]
- Undo: ["leftControl", "z"]
- Redo: ["leftControl", "y"]
- Select all: ["leftControl", "a"]
- Find: ["leftControl", "f"]
- Save: ["leftControl", "s"]

**Browser:**
- New tab: ["leftControl", "t"]
- Close tab: ["leftControl", "w"]
- Address bar: ["leftControl", "l"]
- Reload: ["leftControl", "r"]''';
    }
    return '';
  }
}

class OpenRouterChatSession {
  final OpenRouterService service;
  final List<Map<String, dynamic>> history;

  OpenRouterChatSession({required this.service, required this.history});

  Future<OpenRouterResponse> sendMessage(String text) async {
    // Add user message to history
    history.add({"role": "user", "content": text});

    return _sendRequest();
  }

  Future<OpenRouterResponse> sendFunctionResponse(
      String functionName, Map<String, dynamic> response) async {
    // Add tool response to history
    history.add({
      "role": "tool",
      "tool_call_id":
          "call_${functionName}_${DateTime.now().millisecondsSinceEpoch}", // This is tricky, OpenAI requires exact ID.
      // Wait, correct OpenAI flow:
      // 1. Assistant message calls function (has tool_calls with id)
      // 2. User/Tool message with role "tool", tool_call_id matching the assistant's call id, and content as string

      // Since AppState structure sends "FunctionResponse" separately but doesn't track ID easily,
      // I need to track the last assistant message's tool calls to match IDs.
      "name": functionName,
      "content": jsonEncode(response)
    });

    // NOTE: Simulating the ID matching is needed.
    // I need to store the last tool calls from the assistant response.

    return _sendRequest();
  }

  // Need to fix the tool_call_id logic.
  // The AppState calls sendMessage(Content.functionResponses(...)).
  // I'll need to update AppState to handle this properly or I hack it here if possible.

  List<Map<String, dynamic>> _lastToolCalls = [];

  Future<OpenRouterResponse> _sendRequest() async {
    final requestBody = {
      "model": service.model,
      "messages": history,
      "tools": OpenRouterService.tools,
    };

    try {
      final response = await http.post(
        Uri.parse(OpenRouterService._baseUrl),
        headers: service._headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'OpenRouter API error: ${response.statusCode} ${response.body}');
      }

      final data = jsonDecode(response.body);
      final choice = data['choices'][0];
      final message = choice['message'];

      // Add assistant message to history
      history.add(message);

      String? content = message['content'];
      List<OpenRouterFunctionCall> functionCalls = [];

      if (message['tool_calls'] != null) {
        _lastToolCalls = List<Map<String, dynamic>>.from(message['tool_calls']);
        for (var toolCall in message['tool_calls']) {
          final function = toolCall['function'];
          functionCalls.add(OpenRouterFunctionCall(
            name: function['name'],
            args: jsonDecode(function['arguments']),
            id: toolCall['id'],
          ));
        }
      } else {
        _lastToolCalls = [];
      }

      return OpenRouterResponse(
        text: content,
        functionCalls: functionCalls,
      );
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Custom method to handle function responses with ID matching
  Future<OpenRouterResponse> sendFunctionResponses(
      List<Map<String, dynamic>> responses) async {
    // responses is a list of {name, response} (from my AppState logic adaptation)

    // Match responses to _lastToolCalls by name
    for (var resp in responses) {
      final name = resp['name'];
      final content = resp['content'];

      // Find matching call ID
      final validCall = _lastToolCalls
          .firstWhere((c) => c['function']['name'] == name, orElse: () => {});
      if (validCall.isNotEmpty) {
        history.add({
          "role": "tool",
          "tool_call_id": validCall['id'],
          "name": name,
          "content": jsonEncode(content)
        });
      }
    }

    return _sendRequest();
  }
}

class OpenRouterResponse {
  final String? text;
  final List<OpenRouterFunctionCall> functionCalls;

  OpenRouterResponse({this.text, required this.functionCalls});
}

class OpenRouterFunctionCall {
  final String name;
  final Map<String, dynamic> args;
  final String id;

  OpenRouterFunctionCall(
      {required this.name, required this.args, required this.id});

  Map<String, dynamic> toJson() => {
        'name': name,
        'args': args,
        'id': id,
      };
}
