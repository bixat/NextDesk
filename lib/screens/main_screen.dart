import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_state.dart';
import '../services/config_service.dart';
import '../widgets/task_card.dart';
import '../widgets/user_prompt_dialog.dart';
import '../config/app_theme.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _controller = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<int> _expandedActions = {};

  @override
  void initState() {
    super.initState();
    // Set up user prompt callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setUserPromptCallback(
        (question) => UserPromptDialog.show(context, question),
      );
    });
  }

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
                        'NextDesk AI Agent',
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
                // Settings button
                IconButton(
                  icon: const Icon(Icons.settings_rounded),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                  tooltip: 'Settings',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surfaceLight,
                    foregroundColor: AppTheme.textSecondary,
                  ),
                ),
                if (isSmallScreen) ...[
                  const SizedBox(width: AppTheme.spaceXs),
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

          // Configuration Warning Banner
          _buildConfigurationWarning(),

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
                        'NextDesk',
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
                // Pause/Resume button
                if (state.isExecuting) ...[
                  IconButton(
                    onPressed: () {
                      if (state.isPaused) {
                        state.resumeExecution();
                      } else {
                        state.pauseExecution();
                      }
                    },
                    icon: Icon(
                      state.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: state.isPaused
                          ? AppTheme.accentGreen
                          : AppTheme.warningOrange,
                    ),
                    tooltip: state.isPaused ? 'Resume' : 'Pause',
                    style: IconButton.styleFrom(
                      backgroundColor: (state.isPaused
                              ? AppTheme.accentGreen
                              : AppTheme.warningOrange)
                          .withOpacity(0.15),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceXs),
                  // Stop button
                  IconButton(
                    onPressed: () {
                      state.stopExecution();
                    },
                    icon: const Icon(
                      Icons.stop_rounded,
                      color: AppTheme.errorRed,
                    ),
                    tooltip: 'Stop',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.errorRed.withOpacity(0.15),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceXs),
                ],
                if (state.agentState.isReasoning && !state.isPaused)
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
                                      final isExpanded =
                                          _expandedActions.contains(index);
                                      return _buildActionLogItem(
                                        log: log,
                                        index: index,
                                        isExpanded: isExpanded,
                                        theme: theme,
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

  Widget _buildConfigurationWarning() {
    return Consumer<ConfigService>(
      builder: (context, config, _) {
        // Check if any required API keys are missing
        final bool geminiMissing = !config.isGeminiConfigured;
        final bool qwenMissing = (config.visionProvider == 'qwen' ||
                config.shortcutsProvider == 'qwen') &&
            !config.isQwenConfigured;

        if (!geminiMissing && !qwenMissing) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceSm,
          ),
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: AppTheme.warningOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.warningOrange.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: AppTheme.warningOrange,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuration Required',
                      style: TextStyle(
                        color: AppTheme.warningOrange,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      geminiMissing
                          ? 'Gemini API key is required. Please configure it in Settings.'
                          : 'Qwen API key is required for selected provider. Please configure it in Settings.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text('Settings'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.warningOrange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm,
                    vertical: AppTheme.spaceXs,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
      },
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

  Widget _buildActionLogItem({
    required Map<String, dynamic> log,
    required int index,
    required bool isExpanded,
    required ThemeData theme,
  }) {
    final hasArgs = log['args'] != null && (log['args'] as Map).isNotEmpty;
    final hasResponse = log['response'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMedium,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: isExpanded ? AppTheme.primaryPurple : AppTheme.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Always visible
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedActions.remove(index);
                } else {
                  _expandedActions.add(index);
                }
              });
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              child: Row(
                children: [
                  // Action icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryBlue.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 14,
                      color: AppTheme.secondaryBlue,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  // Function name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log['function'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (!isExpanded && hasArgs)
                          Text(
                            _formatArgs(log['args']),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textTertiary,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Expand icon
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: AppTheme.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (isExpanded) ...[
            const Divider(height: 1, color: AppTheme.borderSubtle),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parameters
                  if (hasArgs) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.input_rounded,
                          size: 14,
                          color: AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: AppTheme.spaceXs),
                        Text(
                          'Parameters',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceXs),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spaceSm),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        _formatJson(log['args']),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  // Response
                  if (hasResponse) ...[
                    if (hasArgs) const SizedBox(height: AppTheme.spaceSm),
                    Row(
                      children: [
                        Icon(
                          Icons.output_rounded,
                          size: 14,
                          color: AppTheme.accentGreen,
                        ),
                        const SizedBox(width: AppTheme.spaceXs),
                        Text(
                          'Response',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceXs),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spaceSm),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        _formatResponse(log['response']),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatArgs(Map<String, dynamic>? args) {
    if (args == null || args.isEmpty) return '';
    return args.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  String _formatJson(dynamic data) {
    if (data == null) return 'null';
    try {
      final encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (e) {
      return data.toString();
    }
  }

  String _formatResponse(dynamic response) {
    if (response == null) return 'null';
    if (response is String) return response;
    return _formatJson(response);
  }
}
