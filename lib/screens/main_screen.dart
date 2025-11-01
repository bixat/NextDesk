import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_state.dart';
import '../widgets/task_card.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _controller = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Consumer<AppState>(
        builder: (context, state, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 800;

              if (isSmallScreen) {
                // Small screen: Show only chat panel with drawer for visualization
                return _buildChatPanel(state, isSmallScreen);
              } else {
                // Large screen: Show both panels side by side
                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildChatPanel(state, isSmallScreen),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildVisualizationPanel(state),
                    ),
                  ],
                );
              }
            },
          );
        },
      ),
      endDrawer: Consumer<AppState>(
        builder: (context, state, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = MediaQuery.of(context).size.width < 800;
              if (!isSmallScreen) return SizedBox.shrink();

              return Drawer(
                width: MediaQuery.of(context).size.width * 0.85,
                child: _buildVisualizationPanel(state),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChatPanel(AppState state, bool isSmallScreen) {
    return Container(
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
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology, color: Colors.purple),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ReAct AI Automation Agent',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (state.model != null)
                  Icon(Icons.check_circle, size: 16, color: Colors.green)
                else
                  Icon(Icons.error_outline, size: 16, color: Colors.orange),
                if (isSmallScreen) ...[
                  SizedBox(width: 12),
                  IconButton(
                    icon: Icon(Icons.analytics_outlined),
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                    tooltip: 'View Agent Status',
                  ),
                ],
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
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !state.isExecuting,
                    decoration: InputDecoration(
                      hintText: 'Try: "Open calculator and calculate 10 + 5"',
                      filled: true,
                      fillColor: Colors.white30,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(state),
                  ),
                ),
                SizedBox(width: 12),
                IconButton(
                  onPressed:
                      state.isExecuting ? null : () => _sendMessage(state),
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
    );
  }

  Widget _buildVisualizationPanel(AppState state) {
    return Container(
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
                Icon(Icons.psychology, size: 20, color: Colors.purple),
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
                        style: TextStyle(fontSize: 12, color: Colors.white70),
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
                      valueColor: AlwaysStoppedAnimation(Colors.purple),
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
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
