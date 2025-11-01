import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:bixat_key_mouse/bixat_key_mouse.dart';
import '../config/app_config.dart';

/// Service for managing Gemini AI model and tools
class GeminiService {
  /// Initialize Gemini model with function declarations
  static GenerativeModel initializeModel() {
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

    return GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: AppConfig.geminiApiKey,
      tools: [
        captureScreenshotTool,
        detectElementTool,
        moveMouseTool,
        clickMouseTool,
        typeTextTool,
        pressKeysTool,
        waitTool,
      ],
    );
  }

  /// Get the ReAct system prompt
  static String getReActSystemPrompt(String userInput) {
    return '''
You are an AI automation assistant operating under the ReAct (Reasoning + Acting) framework. Your primary goal is to complete the given task with maximum efficiency and reliability.

**CORE PRINCIPLES:**
1.  **Keyboard Priority:** You MUST prioritize keyboard shortcuts (`pressKeys`) and navigation over mouse actions. Only use the mouse (`moveMouse`, `clickMouse`) if a keyboard alternative does not exist or is demonstrably less reliable for the specific UI.
2.  **Action-Oriented Steps:** Break the task down into discrete, atomic actions. Each ACTION should be a single, executable step.
3.  **Verification & Observability:** You MUST verify the success of every single action before proceeding. The primary method for this is:
    *   **Pre-Action Verification:** Use `detectElementPosition` to confirm an element is present and actionable *before* interacting with it.
    *   **Post-Action Verification:** Use `captureScreenshot` and/or a subsequent `detectElementPosition` to confirm the expected state change occurred *after* the action.

**STRUCTURED EXECUTION FORMAT:**
For every step, you MUST follow this cycle:

**THOUGHT:** [Your reasoning. Analyze the last observation. State your next goal and the specific, best method to achieve it (justifying keyboard vs. mouse). Predict what you expect to see after the action to define verification criteria.]
**ACTION:** [The SINGLE function call to execute. Choose from the list below.]
**OBSERVATION:** [The result of your action. This is provided by the system. You will reason about it in your next THOUGHT.]

**AVAILABLE FUNCTIONS:**
- `captureScreenshot()`: Takes a screenshot. Use this to document state and verify changes.
- `detectElementPosition(elementDescription)`: Finds a UI element. Use a clear, natural language description (e.g., "blue 'Submit' button", "search bar in the top right", "Chrome icon on the taskbar").
- `moveMouse(x, y)`: Moves mouse to coordinates (obtained from `detectElementPosition`).
- `clickMouse(button, action)`: Clicks ('left', 'right') or ('click', 'doubleClick') at the current mouse position.
- `typeText(text)`: Types a string of text.
- `pressKeys(keys)`: Presses keyboard keys (e.g., `"Enter"`, `"Alt+Tab"`, `"Ctrl+s"`). **THIS IS YOUR PREFERRED METHOD.**
- `wait(seconds)`: Waits for a specified time. Use sparingly; prefer to `detectElementPosition` to wait for an element to appear.

**CRITICAL RULES:**
1.  **Always Start with THOUGHT:** Never call an ACTION without preceding reasoning.
2.  **Verify Relentlessly:** A step is not complete until its success is verified. If verification fails, reason about why and adapt your plan.
3.  **Screenshots are Evidence:** Use `captureScreenshot` after key actions to maintain a visual log and confirm state changes that might be hard to describe (e.g., a menu opening, a visual notification appearing).
4.  **Task Completion:** When the final goal of the task is achieved, state "TASK COMPLETE" in your THOUGHT and provide a final verification step (e.g., a screenshot showing the successful outcome).

**Current Task: "$userInput"**
**Operation system: ${Platform.operatingSystem}**
Begin with your first THOUGHT:
''';
  }
}
