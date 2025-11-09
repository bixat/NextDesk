import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:bixat_key_mouse/bixat_key_mouse.dart';
import '../config/app_config.dart';
import 'config_service.dart';

/// Service for managing Gemini AI model and tools
class GeminiService {
  /// Initialize Gemini model with function declarations
  static GenerativeModel? initializeModel(ConfigService? config) {
    // Get API key from config or fallback to AppConfig
    final apiKey = config?.geminiApiKey ?? AppConfig.geminiApiKey;

    // Return null if no API key is configured
    if (apiKey.isEmpty) {
      return null;
    }
    // Define function declarations for Gemini
    final captureScreenshotTool = Tool(
      functionDeclarations: [
        FunctionDeclaration(
          'captureScreenshot',
          'Captures a screenshot of the current screen',
          Schema(SchemaType.object),
        ),
      ],
    );

    final detectElementTool = Tool(
      functionDeclarations: [
        FunctionDeclaration(
          'detectElementPosition',
          'Detects the pixel coordinates of a UI element in the current screenshot using AI vision',
          Schema(
            SchemaType.object,
            properties: {
              'elementDescription': Schema(SchemaType.string,
                  description:
                      'Natural language description of the UI element to locate (e.g., "Submit button", "Username text field", "Close icon")'),
            },
            requiredProperties: ['elementDescription'],
          ),
        ),
      ],
    );

    final moveMouseTool = Tool(
      functionDeclarations: [
        FunctionDeclaration(
          'moveMouse',
          'Moves the mouse cursor to specified coordinates',
          Schema(
            SchemaType.object,
            properties: {
              'x': Schema(SchemaType.integer,
                  description: 'X coordinate on screen'),
              'y': Schema(SchemaType.integer,
                  description: 'Y coordinate on screen'),
            },
            requiredProperties: ['x', 'y'],
          ),
        ),
      ],
    );

    final clickMouseTool = Tool(
      functionDeclarations: [
        FunctionDeclaration(
          'clickMouse',
          'Clicks a mouse button at current position',
          Schema(
            SchemaType.object,
            properties: {
              'button': Schema(SchemaType.string,
                  description: 'Mouse button to click: left, right, or middle',
                  enumValues: ['left', 'right', 'middle']),
              'action': Schema(SchemaType.string,
                  description: 'Type of action: click, press, or release',
                  enumValues: ['click', 'press', 'release']),
            },
          ),
        ),
      ],
    );

    final typeTextTool = Tool(
      functionDeclarations: [
        FunctionDeclaration(
          'typeText',
          'Types text using the keyboard',
          Schema(
            SchemaType.object,
            properties: {
              'text': Schema(SchemaType.string, description: 'Text to type'),
            },
            requiredProperties: ['text'],
          ),
        ),
      ],
    );

    final pressKeysTool = Tool(
      functionDeclarations: [
        FunctionDeclaration(
          'pressKeys',
          'Presses a keyboard keys',
          Schema(
            SchemaType.object,
            properties: {
              'keys': Schema(
                SchemaType.array,
                description: 'Key to press [cmd, space]',
                items: Schema(
                  SchemaType.string,
                  enumValues: UniversalKey.values.map((e) => e.name).toList(),
                ),
              ),
            },
            requiredProperties: ['keys'],
          ),
        ),
      ],
    );

    final waitTool = Tool(
      functionDeclarations: [
        FunctionDeclaration(
          'wait',
          'Waits for a specified number of seconds',
          Schema(
            SchemaType.object,
            properties: {
              'seconds': Schema(SchemaType.number,
                  description: 'Number of seconds to wait'),
            },
            requiredProperties: ['seconds'],
          ),
        ),
      ],
    );

    final getShortcutsTool = Tool(
      functionDeclarations: [
        FunctionDeclaration(
          'getShortcuts',
          'Fetches keyboard shortcuts for a specific app or system task using AI. Use this to discover shortcuts instead of using vision/mouse.',
          Schema(
            SchemaType.object,
            properties: {
              'query': Schema(SchemaType.string,
                  description:
                      'Description of the app or task to get shortcuts for (e.g., "Chrome browser", "VS Code", "macOS window management", "text editing")'),
            },
            requiredProperties: ['query'],
          ),
        ),
      ],
    );

    final askUserTool = Tool(
      functionDeclarations: [
        FunctionDeclaration(
          'askUser',
          'Asks the user a question and waits for their response. Use this when you need user input to proceed, especially when the actual UI state differs from expectations (e.g., found "Update" button instead of "Get" button).',
          Schema(
            SchemaType.object,
            properties: {
              'question': Schema(SchemaType.string,
                  description:
                      'The question to ask the user. Be clear and specific about the situation and what options are available (e.g., "WhatsApp is already installed. I see an \'Update\' button instead of \'Get\'. Would you like me to update it or cancel?")'),
            },
            requiredProperties: ['question'],
          ),
        ),
      ],
    );

    return GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      tools: [
        captureScreenshotTool,
        detectElementTool,
        moveMouseTool,
        clickMouseTool,
        typeTextTool,
        pressKeysTool,
        waitTool,
        getShortcutsTool,
        askUserTool,
      ],
      // Note: Cannot use responseMimeType with function calling
      // Gemini will return text responses that we'll parse
    );
  }

  /// Get the ReAct system prompt
  static String getReActSystemPrompt(String userInput) {
    final os = Platform.operatingSystem;
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

**WORKFLOW EXAMPLES:**

**Example 1: Keyboard-Only Success**
Task: "Open Chrome and search for cats"

THOUGHT: I'll use Spotlight with Cmd+Space to open Chrome
→ pressKeys(["leftCommand", "space"])

THOUGHT: Type 'Chrome' to search for it
→ typeText("Chrome")

THOUGHT: Press Enter to open Chrome
→ pressKeys(["returnKey"])

THOUGHT: Wait for Chrome to open, then focus address bar with Cmd+L
→ wait(1.5)
→ pressKeys(["leftCommand", "l"])

THOUGHT: Type search query
→ typeText("cats")

THOUGHT: Press Enter to search
→ pressKeys(["returnKey"])

THOUGHT: TASK COMPLETE - Chrome is open and searching for cats
→ captureScreenshot()

**Example 2: Vision Fallback with User Confirmation**
Task: "Download WhatsApp from App Store"

THOUGHT: I'll use Spotlight to open App Store
→ pressKeys(["leftCommand", "space"])

THOUGHT: Keyboard approach failed for finding the Get button. Switching to vision fallback
→ detectElementPosition("Get button")
OBSERVATION: {success: true, x: 500, y: 300, screenshot_description: "App Store page showing WhatsApp with 'Update' button instead of 'Get' button"}

THOUGHT: Vision detected 'Update' button instead of 'Get' button. I need to ask the user how to proceed
→ askUser("WhatsApp is already installed. I see an 'Update' button instead of 'Get'. Would you like me to update it or cancel?")
OBSERVATION: {success: true, user_response: "Yes, proceed"}

THOUGHT: User confirmed to proceed with Update. Clicking the Update button
→ moveMouse(500, 300)
→ clickMouse("left", "click")

**Current Task: "$userInput"**
**Operating System: $os**

Begin with your first THOUGHT:
''';
  }

  /// Get common keyboard shortcuts for the operating system
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
