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

  // Getters
  ReActAgentState get agentState => _agentState;
  List<String> get thoughts => thoughtLog;
  GenerativeModel? get model => _model;
}

