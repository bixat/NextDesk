import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:bixat_key_mouse/bixat_key_mouse.dart';
import 'package:screen_capturer/screen_capturer.dart';
import 'package:isar/isar.dart' hide Schema;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart' hide Direction;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

// Models
part 'main.g.dart';

@collection
class Task {
  Id id = Isar.autoIncrement;
  String prompt = '';
  List<String> thoughts = []; // NEW: Store reasoning thoughts
  List<String> steps = [];
  bool completed = false;
  DateTime createdAt = DateTime.now();
}

/// Result class for element detection
class DetectionResult {
  final String status;
  final int? x;
  final int? y;
  final String? screenshotDescription;
  final double? confidence;
  final Map<String, int>? imageSize;
  final String? errorMessage;

  DetectionResult({
    required this.status,
    this.x,
    this.y,
    this.screenshotDescription,
    this.confidence,
    this.imageSize,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'x': x,
      'y': y,
      'screenshot_description': screenshotDescription,
      'confidence': confidence,
      'image_size': imageSize,
      'error_message': errorMessage,
    };
  }
}

/// ReAct Agent State Management
class ReActAgentState {
  String currentThought = '';
  String lastObservation = '';
  String nextAction = '';
  int iterationCount = 0;
  bool isReasoning = false;

  void reset() {
    currentThought = '';
    lastObservation = '';
    nextAction = '';
    iterationCount = 0;
    isReasoning = false;
  }

  Map<String, dynamic> toJson() {
    return {
      'current_thought': currentThought,
      'last_observation': lastObservation,
      'next_action': nextAction,
      'iteration_count': iterationCount,
      'is_reasoning': isReasoning,
    };
  }
}

/// Element Position Detection Tool
class ElementPositionDetector {
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

// Automation Functions that will be called by Gemini
class AutomationFunctions {
  final ScreenCapturer _screenCapturer = ScreenCapturer.instance;
  Uint8List? lastScreenshot;
  final Function(String) onStatusUpdate;
  final Function() onScreenshotTaken;

  AutomationFunctions({
    required this.onStatusUpdate,
    required this.onScreenshotTaken,
  });

  // Capture screenshot function
  Future<Map<String, dynamic>> captureScreenshot() async {
    try {
      final capturedImage = await _screenCapturer.capture(
        mode: CaptureMode.screen,
      );
      if (capturedImage != null) {
        lastScreenshot = capturedImage.imageBytes;
        lastScreenshot = await resizeImage(lastScreenshot!);
        onScreenshotTaken();
        return {
          'success': true,
          'message': 'Screenshot captured successfully',
          'hasImage': true,
        };
      }
      return {
        'success': false,
        'message': 'Failed to capture screenshot',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error capturing screenshot: $e',
      };
    }
  }

  Future<Uint8List?> resizeImage(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        return null;
      }

      // Determine new dimensions while preserving aspect ratio
      final resizedImage = img.copyResize(
        image,
        width: (image.width / 3).toInt(),
        height: (image.height / 3).toInt(),
      );

      // Encode the resized image to a PNG byte array
      return img.encodePng(resizedImage);
    } catch (e) {
      print('Error creating thumbnail: $e');
      return null;
    }
  }

  // Detect element position function
  Future<Map<String, dynamic>> detectElementPosition({
    required String elementDescription,
  }) async {
    try {
      if (lastScreenshot == null) {
        return {
          'success': false,
          'message':
              'No screenshot available. Please capture a screenshot first.',
        };
      }

      onStatusUpdate('Detecting element: $elementDescription');

      final result = await ElementPositionDetector.detectElementPosition(
        lastScreenshot!,
        elementDescription,
      );

      if (result.status == 'success') {
        return {
          'success': true,
          'message':
              'Element detected at coordinates (${result.x}, ${result.y})',
          'x': result.x,
          'y': result.y,
          'confidence': result.confidence,
          'element_description': elementDescription,
        };
      } else {
        return {
          'success': false,
          'message': result.errorMessage ?? 'Failed to detect element',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error detecting element position: $e',
      };
    }
  }

  // Move mouse function
  Map<String, dynamic> moveMouse({
    required int x,
    required int y,
  }) {
    print("Moving mouse to ($x, $y)");
    try {
      BixatKeyMouse.moveMouse(
        x: x,
        y: y,
      );
      return {
        'success': true,
        'message': 'Mouse moved to ($x, $y)',
        'position': {'x': x, 'y': y},
      };
    } catch (e) {
      print(e);
      return {
        'success': false,
        'message': 'Error moving mouse: $e',
      };
    }
  }

  // Click mouse function
  Map<String, dynamic> clickMouse({
    String button = 'left',
    String action = 'click',
  }) {
    try {
      final mouseButton = switch (button.toLowerCase()) {
        'left' => MouseButton.left,
        'middle' => MouseButton.middle,
        _ => MouseButton.right,
      };

      BixatKeyMouse.pressMouseButton(
          button: mouseButton, direction: Direction.click);

      return {
        'success': true,
        'message': 'Mouse $button button $action successful',
        'button': button,
        'action': action,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error clicking mouse: $e',
      };
    }
  }

  // Type text function
  Map<String, dynamic> typeText({required String text}) {
    try {
      BixatKeyMouse.enterText(text: text);
      return {
        'success': true,
        'message': 'Text typed successfully',
        'text': text,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error typing text: $e',
      };
    }
  }

  // Press key function
  Future<Map<String, dynamic>> pressKeys({required List keys}) async {
    try {
      final unvKeys = <UniversalKey>[];
      for (var key in keys) {
        final unvKey = UniversalKey.values.firstWhere((e) => e.name == key);
        unvKeys.add(unvKey);
      }
      BixatKeyMouse.simulateKeyCombination(keys: unvKeys);
      return {
        'success': true,
        'message': 'Keys pressed: $keys',
        'keys': keys,
      };
    } catch (e) {
      print(e);
      return {
        'success': false,
        'message': 'Error pressing key: $e',
      };
    }
  }

  // Wait function
  Future<Map<String, dynamic>> wait({required double seconds}) async {
    try {
      await Future.delayed(Duration(milliseconds: (seconds * 1000).toInt()));
      return {
        'success': true,
        'message': 'Waited for $seconds seconds',
        'duration': seconds,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error waiting: $e',
      };
    }
  }
}

// Providers
class AppState extends ChangeNotifier {
  GenerativeModel? _model;
  late Isar _isar;
  late AutomationFunctions _automationFunctions;
  final ReActAgentState _agentState =
      ReActAgentState(); // NEW: ReAct agent state

  List<Task> tasks = [];
  Task? currentTask;
  String? currentStep;
  bool isExecuting = false;
  Uint8List? lastScreenshot;
  String status = 'Ready';
  List<Map<String, dynamic>> executionLog = [];
  List<String> thoughtLog = []; // NEW: Store agent thoughts

  AppState() {
    _automationFunctions = AutomationFunctions(
      onStatusUpdate: (msg) {
        status = msg;
        notifyListeners();
      },
      onScreenshotTaken: () {
        lastScreenshot = _automationFunctions.lastScreenshot;
        notifyListeners();
      },
    );
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize Isar
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open([TaskSchema], directory: dir.path);
    await loadTasks();

    // Initialize Gemini with function declarations
    const apiKey = 'AIzaSyCqF8yEv4MwA_rp6vzdUckXMt0qGHRg6X4';
    _initializeGemini(apiKey);
  }

  Future<void> _initializeGemini(String apiKey) async {
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
    _model = GenerativeModel(
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
      ],
    );
  }

  Future<void> loadTasks() async {
    tasks = await _isar.tasks.where().findAll();
    notifyListeners();
  }

  Future<void> processUserInput(String input) async {
    if (_model == null) {
      status = 'Please add your Gemini API key in the code';
      notifyListeners();
      return;
    }

    isExecuting = true;
    status = 'Starting ReAct agent reasoning...';
    _agentState.reset();
    thoughtLog.clear();
    executionLog.clear();
    notifyListeners();

    try {
      // Create and save task
      final task = Task()..prompt = input;
      await _isar.writeTxn(() async {
        await _isar.tasks.put(task);
      });
      currentTask = task;
      await loadTasks();

      // Create chat session with ReAct system prompt
      final chat = _model!.startChat(history: []);

      // ReAct system prompt with structured reasoning format
      final systemPrompt = '''
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

            **Current Task: "$input"**
            **Operation system: ${Platform.operatingSystem}**
            Begin with your first THOUGHT:
            ''';

      // Send initial message
      var response = await chat.sendMessage(Content.text(systemPrompt));
      _agentState.iterationCount = 1;

      // ReAct loop
      final int maxIterations = 30;

      while (_agentState.iterationCount <= maxIterations) {
        // Parse the response for ReAct components
        final responseText = response.text ?? '';
        _parseReActResponse(responseText);

        // Store the thought
        if (_agentState.currentThought.isNotEmpty) {
          thoughtLog.add(_agentState.currentThought);
          if (currentTask != null) {
            currentTask!.thoughts.add(_agentState.currentThought);
          }
        }

        notifyListeners();

        // Check if task is complete
        if (_agentState.currentThought
                .toLowerCase()
                .contains('task complete') ||
            _agentState.currentThought.toLowerCase().contains('completed')) {
          break;
        }

        // Execute action if specified
        final functionCalls = response.functionCalls.toList();
        if (functionCalls.isNotEmpty) {
          for (final functionCall in functionCalls) {
            currentStep =
                '${functionCall.name}(${jsonEncode(functionCall.args)})';
            notifyListeners();

            // Log the execution
            executionLog.add({
              'function': functionCall.name,
              'args': functionCall.args,
              'timestamp': DateTime.now().toIso8601String(),
              'thought': _agentState.currentThought,
            });
            print(functionCall.toJson());

            // Execute the function
            final result = await _executeFunction(functionCall);
            _agentState.lastObservation = jsonEncode(result);

            // Send observation back to continue ReAct cycle
            response = await chat.sendMessage(
              Content.functionResponses([
                FunctionResponse(functionCall.name, result),
              ]),
            );
          }
        } else {
          // If no function call, ask for next step with observation
          response = await chat.sendMessage(
            Content.text(
                'OBSERVATION: No action taken. Please provide your next THOUGHT and ACTION.'),
          );
        }

        _agentState.iterationCount++;

        // Small delay between iterations
        await Future.delayed(Duration(milliseconds: 800));
      }

      // Mark task as completed
      if (currentTask != null) {
        currentTask!.completed = true;
        currentTask!.steps = executionLog.map((e) => jsonEncode(e)).toList();
        await _isar.writeTxn(() async {
          await _isar.tasks.put(currentTask!);
        });
      }

      status =
          'Task completed successfully in ${_agentState.iterationCount} iterations!';
    } catch (e) {
      status = 'Error: $e';
      print('Error: $e');
    } finally {
      isExecuting = false;
      currentStep = null;
      _agentState.isReasoning = false;
      notifyListeners();
    }
  }

  void _parseReActResponse(String response) {
    // Parse THOUGHT, ACTION, and OBSERVATION from response
    final thoughtMatch = RegExp(r'THOUGHT:\s*(.*?)(?=ACTION:|OBSERVATION:|$)',
            caseSensitive: false, dotAll: true)
        .firstMatch(response);
    final actionMatch = RegExp(r'ACTION:\s*(.*?)(?=OBSERVATION:|THOUGHT:|$)',
            caseSensitive: false, dotAll: true)
        .firstMatch(response);
    final observationMatch = RegExp(
            r'OBSERVATION:\s*(.*?)(?=THOUGHT:|ACTION:|$)',
            caseSensitive: false,
            dotAll: true)
        .firstMatch(response);

    _agentState.currentThought = thoughtMatch?.group(1)?.trim() ?? '';
    _agentState.nextAction = actionMatch?.group(1)?.trim() ?? '';

    if (observationMatch != null) {
      _agentState.lastObservation = observationMatch.group(1)?.trim() ?? '';
    }

    _agentState.isReasoning = _agentState.currentThought.isNotEmpty;
  }

  Future<Map<String, dynamic>> _executeFunction(FunctionCall call) async {
    print("Calling function: ${call.name} with args: ${call.args}");
    try {
      switch (call.name) {
        case 'captureScreenshot':
          return await _automationFunctions.captureScreenshot();

        case 'detectElementPosition':
          return await _automationFunctions.detectElementPosition(
            elementDescription: call.args['elementDescription'] as String,
          );

        case 'moveMouse':
          return _automationFunctions.moveMouse(
              x: call.args['x'] as int, y: call.args['y'] as int);

        case 'clickMouse':
          return _automationFunctions.clickMouse(
            button: call.args['button'] as String? ?? 'left',
            action: call.args['action'] as String? ?? 'click',
          );

        case 'typeText':
          return _automationFunctions.typeText(
            text: call.args['text'] as String,
          );

        case 'pressKeys':
          return _automationFunctions.pressKeys(
            keys: call.args['keys'] as List,
          );

        case 'wait':
          return await _automationFunctions.wait(
            seconds: (call.args['seconds'] as num).toDouble(),
          );

        default:
          return {
            'success': false,
            'message': 'Unknown function: ${call.name}',
          };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error executing ${call.name}: $e',
      };
    }
  }

  // NEW: Get agent state for UI
  ReActAgentState get agentState => _agentState;
  List<String> get thoughts => thoughtLog;
}

// UI Updates for ReAct Agent
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReAct AI Automation',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppState>(
        builder: (context, state, _) {
          return Row(
            children: [
              // Chat Panel
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.white10),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border:
                              Border(bottom: BorderSide(color: Colors.white10)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.psychology,
                                color: Colors.purple), // Changed icon
                            SizedBox(width: 12),
                            Text(
                              'ReAct AI Automation Agent', // Updated title
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            Spacer(),
                            if (state._model != null)
                              Icon(Icons.check_circle,
                                  size: 16, color: Colors.green)
                            else
                              Icon(Icons.error_outline,
                                  size: 16, color: Colors.orange),
                          ],
                        ),
                      ),

                      // Tasks List
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: state.tasks.length,
                          itemBuilder: (context, index) {
                            final task = state.tasks[index];
                            return TaskCard(task: task)
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: 0.2, end: 0);
                          },
                        ),
                      ),

                      // Input Area
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border:
                              Border(top: BorderSide(color: Colors.white10)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                enabled: !state.isExecuting,
                                decoration: InputDecoration(
                                  hintText:
                                      'Try: "Open calculator and calculate 10 + 5"',
                                  filled: true,
                                  fillColor: Colors.white30,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                onSubmitted: (_) => _sendMessage(state),
                              ),
                            ),
                            SizedBox(width: 12),
                            IconButton(
                              onPressed: state.isExecuting
                                  ? null
                                  : () => _sendMessage(state),
                              icon: Icon(Icons.send_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Visualization Panel with ReAct components
              Expanded(
                flex: 3,
                child: Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ReAct Agent Status
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.psychology,
                                size: 20, color: Colors.purple),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ReAct Agent',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.purple,
                                    ),
                                  ),
                                  Text(
                                    'Iteration ${state.agentState.iterationCount}',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            if (state.agentState.isReasoning)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.purple),
                                ),
                              ),
                          ],
                        ),
                      ).animate().fadeIn(),

                      SizedBox(height: 20),

                      // Current Thought
                      if (state.agentState.currentThought.isNotEmpty) ...[
                        Text(
                          'Current Thought',
                          style: TextStyle(fontSize: 14, color: Colors.white54),
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.05),
                            border: Border.all(
                                color: Colors.purple.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            state.agentState.currentThought,
                            style: TextStyle(
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ).animate().fadeIn(),
                        SizedBox(height: 20),
                      ],

                      // Thought History
                      if (state.thoughts.isNotEmpty) ...[
                        Text(
                          'Thought History',
                          style: TextStyle(fontSize: 14, color: Colors.white54),
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white10),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black26,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.all(12),
                              itemCount: state.thoughts.length,
                              itemBuilder: (context, index) {
                                final thought = state.thoughts[index];
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline,
                                        size: 14,
                                        color: Colors.purple,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          thought,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],

                      // Execution Log
                      if (state.executionLog.isNotEmpty) ...[
                        Text(
                          'Execution Log',
                          style: TextStyle(fontSize: 14, color: Colors.white54),
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          flex: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white10),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black26,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.all(12),
                              itemCount: state.executionLog.length,
                              itemBuilder: (context, index) {
                                final log = state.executionLog[index];
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.play_arrow,
                                        size: 12,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${log['function']}(${_formatArgs(log['args'])})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ).animate().fadeIn(),
                        SizedBox(height: 20),
                      ],

                      // Screenshot Preview
                      if (state.lastScreenshot != null) ...[
                        Text(
                          'Current View',
                          style: TextStyle(fontSize: 14, color: Colors.white54),
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                state.lastScreenshot!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ).animate().fadeIn(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _sendMessage(AppState state) {
    if (_controller.text.trim().isEmpty) return;
    state.processUserInput(_controller.text);
    _controller.clear();
  }

  String _formatArgs(Map<String, dynamic>? args) {
    if (args == null || args.isEmpty) return '';
    return args.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }
}

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              task.completed ? Colors.green.withOpacity(0.3) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                task.completed ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: task.completed ? Colors.green : Colors.white54,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.prompt,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (task.thoughts.isNotEmpty) ...[
            // Updated to show thoughts
            SizedBox(height: 8),
            Text(
              '${task.thoughts.length} thoughts • ${task.steps.length} actions',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
          SizedBox(height: 4),
          Text(
            _formatTime(task.createdAt),
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
