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

/// Main application state provider
class AppState extends ChangeNotifier {
  GenerativeModel? _model;
  late Isar _isar;
  late AutomationService _automationService;
  final ReActAgentState _agentState = ReActAgentState();

  List<Task> tasks = [];
  Task? currentTask;
  String? currentStep;
  bool isExecuting = false;
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
    );
  }

  AppState() {
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
    );
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize Isar
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open([TaskSchema], directory: dir.path);
    await loadTasks();

    // Initialize Gemini
    _model = GeminiService.initializeModel();
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
      final int maxIterations = 30;

      while (_agentState.iterationCount <= maxIterations) {
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
            print('Function result: $result');

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

  // Getters
  ReActAgentState get agentState => _agentState;
  List<String> get thoughts => thoughtLog;
  GenerativeModel? get model => _model;
}
