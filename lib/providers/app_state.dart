import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/openrouter_service.dart';
import 'package:isar/isar.dart' hide Schema;
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';
import '../models/react_agent_state.dart';
import '../services/automation_service.dart';
// import '../services/gemini_service.dart';
import '../services/config_service.dart';

/// Main application state provider
class AppState extends ChangeNotifier {
  OpenRouterService? _model;
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

    // Initialize LLM Service
    _model = OpenRouterService.initialize(config);
  }

  /// Reinitialize services (e.g., after API key changes)
  Future<void> reinitializeServices() async {
    status = 'Reinitializing services...';
    notifyListeners();

    // Reinitialize model with new config
    _model = OpenRouterService.initialize(config);

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

    // Check OpenRouter API key (always needed for main model)
    if (!config!.isOpenRouterConfigured) {
      return '⚠️ OpenRouter API key not configured. Please add your API key in Settings.';
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
          'OpenRouter service not initialized. Please configure API key in Settings.';
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
      final systemPrompt = OpenRouterService.getReActSystemPrompt(input);

      // Send initial message
      OpenRouterResponse response;
      try {
        response = await chat.sendMessage(systemPrompt);
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
          if (response.text != null && response.text!.isNotEmpty) {
            responseText = response.text!;
          } else if (response.functionCalls.isNotEmpty) {
            responseText = 'ACTION: Function call detected';
          } else {
            print('Warning: Response has no text or function calls');
            responseText = '';
          }
        } catch (e) {
          print('Warning: Could not get response.text: $e');
          if (response.functionCalls.isNotEmpty) {
            responseText = 'ACTION: Function call detected';
          } else {
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
        final functionCalls = response.functionCalls;
        if (functionCalls.isNotEmpty) {
          List<Map<String, dynamic>> toolOutputs = [];

          for (final functionCall in functionCalls) {
            currentStep =
                '${functionCall.name}(${jsonEncode(functionCall.args)})';
            notifyListeners();

            // Execute the function
            // We need to construct a compatible FunctionCall object or change _executeFunction
            // _executeFunction expects a FunctionCall, but currently it's google's type.
            // I need to change _executeFunction signature too.
            // But for now let's make a mock object or modify logic.

            // Wait, I can just pass name and args to _executeFunction separately or creates a map.
            // _executeFunction uses "FunctionCall call". This type is from google package.
            // I need to update _executeFunction first.

            final result =
                await _executeFunction(functionCall.name, functionCall.args);

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
            // print(functionCall.toJson()); // toJson might need to be implemented in OpenRouterFunctionCall

            toolOutputs.add({'name': functionCall.name, 'content': result});
          }
          // Send observation back to continue ReAct cycle
          try {
            response = await chat.sendFunctionResponses(toolOutputs);
          } catch (e) {
            print('Error sending function response: $e');
            status = 'Error in ReAct loop: $e';
            notifyListeners();
            break;
          }
        } else {
          // If no function call, ask for next step with observation
          try {
            response = await chat.sendMessage(
              'OBSERVATION: No action taken. Please provide your next THOUGHT and ACTION.',
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

  Future<Map<String, dynamic>> _executeFunction(
      String name, Map<String, dynamic> args) async {
    print("Calling function: ${name} with args: ${args}");
    try {
      switch (name) {
        case 'captureScreenshot':
          return await _automationService.captureScreenshot();

        case 'detectElementPosition':
          return await _automationService.detectElementPosition(
            elementDescription: args['elementDescription'] as String,
          );

        case 'moveMouse':
          return _automationService.moveMouse(
              x: args['x'] as int, y: args['y'] as int);

        case 'clickMouse':
          return _automationService.clickMouse(
            button: args['button'] as String? ?? 'left',
            action: args['action'] as String? ?? 'click',
          );

        case 'typeText':
          return _automationService.typeText(
            text: args['text'] as String,
          );

        case 'pressKeys':
          return _automationService.pressKeys(
            keys: args['keys'] as List,
          );

        case 'wait':
          return await _automationService.wait(
            seconds: (args['seconds'] as num).toDouble(),
          );

        case 'getShortcuts':
          return await _automationService.getShortcuts(
            query: args['query'] as String,
          );

        case 'askUser':
          return await _automationService.askUser(
            question: args['question'] as String,
          );

        default:
          return {
            'success': false,
            'message': 'Unknown function: ${name}',
          };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error executing ${name}: $e',
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
  OpenRouterService? get model => _model;
}
