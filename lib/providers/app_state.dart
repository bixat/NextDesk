import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:isar/isar.dart' hide Schema;
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';
import '../models/react_agent_state.dart';
import '../services/automation_service.dart';
import '../services/gemini_service.dart';
import '../services/config_service.dart';

/// Main application state provider
class AppState extends ChangeNotifier {
  GenerativeModel? _model;
  late Isar _isar;
  late AutomationService _automationService;
  final ReActAgentState _agentState = ReActAgentState();
  final ConfigService? config;

  List<Task> tasks = [];
  Task? currentTask;
  String? currentStep;
  bool isExecuting = false;
  bool isPaused = false;
  bool shouldStop = false;
  Uint8List? lastScreenshot;
  String status = 'Ready';
  List<Map<String, dynamic>> executionLog = [];
  List<String> thoughtLog = [];

  // User prompt handling
  Future<String> Function(String question)? _userPromptCallback;

  void setUserPromptCallback(
      Future<String> Function(String question) callback) {
    _userPromptCallback = callback;
    // Update automation service with the callback
    _automationService = AutomationService(
      onStatusUpdate: (msg) {
        status = msg;
        notifyListeners();
      },
      onScreenshotTaken: () {
        lastScreenshot = _automationService.lastScreenshot;
        notifyListeners();
      },
      onUserPrompt: _userPromptCallback,
      config: config,
    );
  }

  AppState({this.config}) {
    _automationService = AutomationService(
      onStatusUpdate: (msg) {
        status = msg;
        notifyListeners();
      },
      onScreenshotTaken: () {
        lastScreenshot = _automationService.lastScreenshot;
        notifyListeners();
      },
      onUserPrompt: _userPromptCallback,
      config: config,
    );
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize Isar
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open([TaskSchema], directory: dir.path);
    await loadTasks();

    // Initialize Gemini
    _model = GeminiService.initializeModel(config);
  }

  /// Reinitialize services (e.g., after API key changes)
  Future<void> reinitializeServices() async {
    status = 'Reinitializing services...';
    notifyListeners();

    // Reinitialize Gemini model with new config
    _model = GeminiService.initializeModel(config);

    // Update status based on model initialization
    if (_model != null) {
      status = 'Connected - Ready to process tasks';
    } else {
      status = 'API key required - Please configure in Settings';
    }
    notifyListeners();
  }

  Future<void> loadTasks() async {
    tasks = await _isar.tasks.where().findAll();
    notifyListeners();
  }

  /// Check if the required API keys are configured based on selected providers
  /// Returns error message if configuration is missing, null if everything is OK
  String? _checkConfiguration() {
    if (config == null) {
      return 'Configuration not initialized. Please restart the app.';
    }

    // Check Gemini API key (always needed for main model)
    if (!config!.isGeminiConfigured) {
      return '⚠️ Gemini API key not configured. Please add your API key in Settings.';
    }

    // Check vision provider API key
    if (config!.visionProvider == 'qwen' && !config!.isQwenConfigured) {
      return '⚠️ Qwen API key not configured. Vision provider is set to Qwen but no API key found. Please configure in Settings.';
    }

    // Check shortcuts provider API key
    if (config!.shortcutsProvider == 'qwen' && !config!.isQwenConfigured) {
      return '⚠️ Qwen API key not configured. Shortcuts provider is set to Qwen but no API key found. Please configure in Settings.';
    }

    return null; // All good
  }

  Future<void> processUserInput(String input) async {
    // Check if required API keys are configured
    final String? configError = _checkConfiguration();
    if (configError != null) {
      status = configError;
      notifyListeners();
      return;
    }

    if (_model == null) {
      status =
          'Gemini model not initialized. Please configure API key in Settings.';
      notifyListeners();
      return;
    }

    isExecuting = true;
    isPaused = false;
    shouldStop = false;
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

      // Get ReAct system prompt
      final systemPrompt = GeminiService.getReActSystemPrompt(input);

      // Send initial message
      GenerateContentResponse response;
      try {
        response = await chat.sendMessage(Content.text(systemPrompt));
      } catch (e) {
        status = 'Error sending initial message: $e';
        print('Error sending initial message: $e');
        notifyListeners();
        isExecuting = false;
        return;
      }
      _agentState.iterationCount = 1;

      // ReAct loop
      final int maxIterations = config?.maxIterations ?? 30;

      while (_agentState.iterationCount <= maxIterations) {
        // Check for stop signal
        if (shouldStop) {
          status = 'Execution stopped by user';
          break;
        }

        // Check for pause signal
        while (isPaused && !shouldStop) {
          status = 'Execution paused';
          notifyListeners();
          await Future.delayed(Duration(milliseconds: 500));
        }

        // Check again after pause
        if (shouldStop) {
          status = 'Execution stopped by user';
          break;
        }

        // Parse the response for ReAct components
        String responseText = '';
        try {
          // Try to get text from response
          if (response.text != null && response.text!.isNotEmpty) {
            responseText = response.text!;
          } else if (response.functionCalls.isNotEmpty) {
            // If no text but has function calls, that's expected
            responseText = 'ACTION: Function call detected';
          } else {
            // No text and no function calls - might be an error
            print('Warning: Response has no text or function calls');
            responseText = '';
          }
        } catch (e) {
          // Handle cases where response.text throws an error
          print('Warning: Could not get response.text: $e');
          print('Response type: ${response.runtimeType}');
          // Check if there are function calls instead
          if (response.functionCalls.isNotEmpty) {
            responseText = 'ACTION: Function call detected';
          } else {
            // Try to continue anyway
            responseText = '';
          }
        }

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
            .toUpperCase()
            .contains('TASK COMPLETE')) {
          break;
        }

        // Execute action if specified
        final functionCalls = response.functionCalls.toList();
        if (functionCalls.isNotEmpty) {
          for (final functionCall in functionCalls) {
            currentStep =
                '${functionCall.name}(${jsonEncode(functionCall.args)})';
            notifyListeners();

            // Execute the function
            final result = await _executeFunction(functionCall);
            _agentState.lastObservation = jsonEncode(result);
            print('Function result: $result');

            // Log the execution with response
            executionLog.add({
              'function': functionCall.name,
              'args': functionCall.args,
              'response': result,
              'timestamp': DateTime.now().toIso8601String(),
              'thought': _agentState.currentThought,
            });
            print(functionCall.toJson());

            // Send observation back to continue ReAct cycle
            try {
              response = await chat.sendMessage(
                Content.functionResponses([
                  FunctionResponse(functionCall.name, result),
                ]),
              );
            } catch (e) {
              print('Error sending function response: $e');
              status = 'Error in ReAct loop: $e';
              notifyListeners();
              break;
            }
          }
        } else {
          // If no function call, ask for next step with observation
          try {
            response = await chat.sendMessage(
              Content.text(
                  'OBSERVATION: No action taken. Please provide your next THOUGHT and ACTION.'),
            );
          } catch (e) {
            print('Error sending text message: $e');
            status = 'Error in ReAct loop: $e';
            notifyListeners();
            break;
          }
        }

        _agentState.iterationCount++;

        // Small delay between iterations
        await Future.delayed(Duration(milliseconds: 800));
      }

      // Mark task as completed
      if (currentTask != null) {
        currentTask!.status = TaskStatus.completed;
        currentTask!.thoughts = thoughtLog;
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

      // Mark task as failed
      if (currentTask != null) {
        currentTask!.status = TaskStatus.failed;
        currentTask!.thoughts = thoughtLog;
        currentTask!.steps = executionLog.map((e) => jsonEncode(e)).toList();
        await _isar.writeTxn(() async {
          await _isar.tasks.put(currentTask!);
        });
      }
    } finally {
      isExecuting = false;
      currentStep = null;
      _agentState.isReasoning = false;
      await loadTasks();
      notifyListeners();
    }
  }

  void _parseReActResponse(String response) {
    // Parse THOUGHT from response text
    // Gemini with function calling returns plain text, not JSON

    // Try to extract THOUGHT: ... pattern
    final thoughtMatch = RegExp(
      r'THOUGHT:\s*(.+?)(?=\n|$)',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(response);

    if (thoughtMatch != null) {
      _agentState.currentThought = thoughtMatch.group(1)?.trim() ?? '';
    } else {
      // If no THOUGHT: prefix, use the whole response (up to 200 chars)
      _agentState.currentThought = response.isNotEmpty
          ? response
              .substring(0, response.length > 200 ? 200 : response.length)
              .trim()
          : 'Processing...';
    }

    _agentState.nextAction = ''; // Action is determined by function calls
    _agentState.isReasoning = _agentState.currentThought.isNotEmpty;
  }

  Future<Map<String, dynamic>> _executeFunction(FunctionCall call) async {
    print("Calling function: ${call.name} with args: ${call.args}");
    try {
      switch (call.name) {
        case 'captureScreenshot':
          return await _automationService.captureScreenshot();

        case 'detectElementPosition':
          return await _automationService.detectElementPosition(
            elementDescription: call.args['elementDescription'] as String,
          );

        case 'moveMouse':
          return _automationService.moveMouse(
              x: call.args['x'] as int, y: call.args['y'] as int);

        case 'clickMouse':
          return _automationService.clickMouse(
            button: call.args['button'] as String? ?? 'left',
            action: call.args['action'] as String? ?? 'click',
          );

        case 'typeText':
          return _automationService.typeText(
            text: call.args['text'] as String,
          );

        case 'pressKeys':
          return _automationService.pressKeys(
            keys: call.args['keys'] as List,
          );

        case 'wait':
          return await _automationService.wait(
            seconds: (call.args['seconds'] as num).toDouble(),
          );

        case 'getShortcuts':
          return await _automationService.getShortcuts(
            query: call.args['query'] as String,
          );

        case 'askUser':
          return await _automationService.askUser(
            question: call.args['question'] as String,
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

  /// Delete a task from the database
  Future<void> deleteTask(int taskId) async {
    await _isar.writeTxn(() async {
      await _isar.tasks.delete(taskId);
    });
    await loadTasks();
  }

  /// Re-run a task with the same prompt
  Future<void> rerunTask(Task task) async {
    await processUserInput(task.prompt);
  }

  /// Pause the current execution
  void pauseExecution() {
    if (isExecuting && !isPaused) {
      isPaused = true;
      status = 'Execution paused';
      notifyListeners();
    }
  }

  /// Resume the paused execution
  void resumeExecution() {
    if (isExecuting && isPaused) {
      isPaused = false;
      status = 'Execution resumed';
      notifyListeners();
    }
  }

  /// Stop the current execution
  void stopExecution() {
    if (isExecuting) {
      shouldStop = true;
      isPaused = false;
      status = 'Stopping execution...';
      notifyListeners();
    }
  }

  // Getters
  ReActAgentState get agentState => _agentState;
  List<String> get thoughts => thoughtLog;
  GenerativeModel? get model => _model;
}
