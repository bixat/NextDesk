import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_state.dart';
import '../widgets/task_card.dart';
import '../config/app_theme.dart';

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
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: AppTheme.borderSubtle),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLg,
              vertical: AppTheme.spaceMd,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                // App icon/logo
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryPurple, AppTheme.secondaryBlue],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ReAct AI Agent',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: state.model != null
                                  ? AppTheme.accentGreen
                                  : AppTheme.warningOrange,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (state.model != null
                                          ? AppTheme.accentGreen
                                          : AppTheme.warningOrange)
                                      .withOpacity(0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceXs),
                          Text(
                            state.model != null ? 'Connected' : 'Initializing',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isSmallScreen) ...[
                  const SizedBox(width: AppTheme.spaceMd),
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined),
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                    tooltip: 'View Agent Status',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceLight,
                      foregroundColor: AppTheme.primaryPurple,
                    ),
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
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(
                top: BorderSide(color: AppTheme.borderSubtle, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !state.isExecuting,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Describe what you want the AI to do...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceMedium,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide:
                            const BorderSide(color: AppTheme.borderMedium),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide:
                            const BorderSide(color: AppTheme.borderMedium),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryPurple,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd,
                        vertical: AppTheme.spaceMd,
                      ),
                      prefixIcon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppTheme.textTertiary,
                        size: 20,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(state),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Container(
                  decoration: BoxDecoration(
                    gradient: state.isExecuting
                        ? null
                        : const LinearGradient(
                            colors: [
                              AppTheme.primaryPurple,
                              AppTheme.secondaryBlue,
                            ],
                          ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: state.isExecuting ? null : AppTheme.shadowGlow,
                  ),
                  child: IconButton(
                    onPressed:
                        state.isExecuting ? null : () => _sendMessage(state),
                    icon: state.isExecuting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                AppTheme.textTertiary,
                              ),
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          state.isExecuting ? AppTheme.surfaceLight : null,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(AppTheme.spaceMd),
                      minimumSize: const Size(48, 48),
                    ),
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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppTheme.backgroundDark,
            AppTheme.backgroundMedium,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ReAct Agent Status
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPurple.withOpacity(0.15),
                  AppTheme.secondaryBlue.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppTheme.primaryPurple.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: AppTheme.shadowMd,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    size: 24,
                    color: AppTheme.primaryPurple,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ReAct Agent',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: AppTheme.spaceXs),
                          Text(
                            'Iteration ${state.agentState.iterationCount}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (state.agentState.isReasoning)
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceSm),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation(AppTheme.primaryPurple),
                      ),
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0),

          const SizedBox(height: AppTheme.spaceLg),

          // Current Thought
          if (state.agentState.currentThought.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.lightbulb_rounded,
                  size: 16,
                  color: AppTheme.warningOrange,
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Text(
                  'Current Thought',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.warningOrange.withOpacity(0.08),
                border: Border.all(
                  color: AppTheme.warningOrange.withOpacity(0.3),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceXs),
                    decoration: BoxDecoration(
                      color: AppTheme.warningOrange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      Icons.psychology_outlined,
                      size: 16,
                      color: AppTheme.warningOrange,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Text(
                      state.agentState.currentThought,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0),
            const SizedBox(height: AppTheme.spaceLg),
          ],

          // Tabbed View for Thought History & Execution Log
          if (state.thoughts.isNotEmpty || state.executionLog.isNotEmpty) ...[
            Expanded(
              flex: 4,
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(AppTheme.radiusMd),
                          topRight: Radius.circular(AppTheme.radiusMd),
                        ),
                        border: Border.all(color: AppTheme.borderMedium),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryPurple,
                              AppTheme.secondaryBlue,
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(AppTheme.radiusMd - 1),
                            topRight: Radius.circular(AppTheme.radiusMd - 1),
                          ),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: AppTheme.textPrimary,
                        unselectedLabelColor: AppTheme.textTertiary,
                        labelStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: theme.textTheme.labelLarge,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_rounded, size: 16),
                                const SizedBox(width: AppTheme.spaceSm),
                                Text('Thoughts'),
                                if (state.thoughts.isNotEmpty) ...[
                                  const SizedBox(width: AppTheme.spaceSm),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusFull),
                                    ),
                                    child: Text(
                                      '${state.thoughts.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.terminal_rounded, size: 16),
                                const SizedBox(width: AppTheme.spaceSm),
                                Text('Actions'),
                                if (state.executionLog.isNotEmpty) ...[
                                  const SizedBox(width: AppTheme.spaceSm),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusFull),
                                    ),
                                    child: Text(
                                      '${state.executionLog.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: AppTheme.borderMedium),
                            right: BorderSide(color: AppTheme.borderMedium),
                            bottom: BorderSide(color: AppTheme.borderMedium),
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(AppTheme.radiusMd),
                            bottomRight: Radius.circular(AppTheme.radiusMd),
                          ),
                          color: AppTheme.surfaceDark,
                        ),
                        child: TabBarView(
                          children: [
                            // Thought History Tab
                            state.thoughts.isEmpty
                                ? _buildEmptyState(
                                    icon: Icons.psychology_outlined,
                                    message: 'No thoughts yet',
                                    color: AppTheme.primaryPurple,
                                  )
                                : ListView.builder(
                                    padding:
                                        const EdgeInsets.all(AppTheme.spaceMd),
                                    itemCount: state.thoughts.length,
                                    itemBuilder: (context, index) {
                                      final thought = state.thoughts[index];
                                      return Container(
                                        margin: const EdgeInsets.only(
                                            bottom: AppTheme.spaceSm),
                                        padding: const EdgeInsets.all(
                                            AppTheme.spaceMd),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceMedium,
                                          borderRadius: BorderRadius.circular(
                                              AppTheme.radiusSm),
                                          border: Border.all(
                                            color: AppTheme.borderSubtle,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(
                                                  AppTheme.spaceXs),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryPurple
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        AppTheme.radiusSm),
                                              ),
                                              child: Text(
                                                '${index + 1}',
                                                style: theme
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  color: AppTheme.primaryPurple,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                                width: AppTheme.spaceMd),
                                            Expanded(
                                              child: Text(
                                                thought,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: AppTheme.textSecondary,
                                                  fontStyle: FontStyle.italic,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ).animate().fadeIn(
                                          duration: 200.ms,
                                          delay: (index * 50).ms);
                                    },
                                  ),
                            // Execution Log Tab
                            state.executionLog.isEmpty
                                ? _buildEmptyState(
                                    icon: Icons.code_rounded,
                                    message: 'No actions executed yet',
                                    color: AppTheme.secondaryBlue,
                                  )
                                : ListView.builder(
                                    padding:
                                        const EdgeInsets.all(AppTheme.spaceMd),
                                    itemCount: state.executionLog.length,
                                    itemBuilder: (context, index) {
                                      final log = state.executionLog[index];
                                      return Container(
                                        margin: const EdgeInsets.only(
                                            bottom: AppTheme.spaceXs),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.spaceMd,
                                          vertical: AppTheme.spaceSm,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceMedium,
                                          borderRadius: BorderRadius.circular(
                                              AppTheme.radiusSm),
                                          border: Border.all(
                                            color: AppTheme.borderSubtle,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.secondaryBlue
                                                    .withOpacity(0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.play_arrow_rounded,
                                                size: 12,
                                                color: AppTheme.secondaryBlue,
                                              ),
                                            ),
                                            const SizedBox(
                                                width: AppTheme.spaceMd),
                                            Expanded(
                                              child: Text(
                                                '${log['function']}(${_formatArgs(log['args'])})',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: AppTheme.textSecondary,
                                                  fontFamily: 'monospace',
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ).animate().fadeIn(
                                          duration: 200.ms,
                                          delay: (index * 30).ms);
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
          ],

          // Screenshot Preview
          if (state.lastScreenshot != null) ...[
            Row(
              children: [
                Icon(
                  Icons.screenshot_monitor_rounded,
                  size: 16,
                  color: AppTheme.accentGreen,
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Text(
                  'Current View',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.borderMedium,
                    width: 2,
                  ),
                  boxShadow: AppTheme.shadowLg,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd - 2),
                  child: Image.memory(
                    state.lastScreenshot!,
                    fit: BoxFit.contain,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .scale(begin: Offset(0.95, 0.95), end: Offset(1, 1)),
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

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: color.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            message,
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatArgs(Map<String, dynamic>? args) {
    if (args == null || args.isEmpty) return '';
    return args.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }
}
