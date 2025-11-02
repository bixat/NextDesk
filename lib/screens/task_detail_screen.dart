import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/task.dart';
import '../config/app_theme.dart';
import '../providers/app_state.dart';

class TaskDetailScreen extends StatelessWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text('Task Details'),
        actions: [
          // Re-run button
          IconButton(
            icon: const Icon(Icons.replay_rounded),
            onPressed: () {
              _showRerunConfirmation(context);
            },
            tooltip: 'Re-run Task',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.surfaceLight,
              foregroundColor: AppTheme.secondaryBlue,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () {
              _showDeleteConfirmation(context);
            },
            tooltip: 'Delete Task',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.surfaceLight,
              foregroundColor: AppTheme.errorRed,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Header Card
            _buildHeaderCard(theme),
            const SizedBox(height: AppTheme.spaceLg),

            // Quick Actions
            _buildQuickActions(context),
            const SizedBox(height: AppTheme.spaceLg),

            // Thoughts Section
            if (task.thoughts.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.psychology_outlined,
                title: 'Thoughts',
                subtitle: '${task.thoughts.length} reasoning steps',
                color: AppTheme.primaryPurple,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              _buildThoughtsList(),
              const SizedBox(height: AppTheme.spaceLg),
            ],

            // Steps/Actions Section
            if (task.steps.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.play_circle_outline_rounded,
                title: 'Execution Steps',
                subtitle: '${task.steps.length} actions performed',
                color: AppTheme.secondaryBlue,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              _buildStepsList(),
              const SizedBox(height: AppTheme.spaceLg),
            ],

            // Empty state if no data
            if (task.thoughts.isEmpty && task.steps.isEmpty) ...[
              _buildEmptyState(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMedium,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: task.isCompleted
              ? AppTheme.accentGreen.withOpacity(0.5)
              : task.isFailed
                  ? AppTheme.errorRed.withOpacity(0.5)
                  : AppTheme.borderMedium,
          width: 2,
        ),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMd,
                  vertical: AppTheme.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? AppTheme.accentGreen.withOpacity(0.15)
                      : task.isFailed
                          ? AppTheme.errorRed.withOpacity(0.15)
                          : AppTheme.warningOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                    color: task.isCompleted
                        ? AppTheme.accentGreen
                        : task.isFailed
                            ? AppTheme.errorRed
                            : AppTheme.warningOrange,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      task.isCompleted
                          ? Icons.check_circle_rounded
                          : task.isFailed
                              ? Icons.error_rounded
                              : Icons.pending_rounded,
                      size: 16,
                      color: task.isCompleted
                          ? AppTheme.accentGreen
                          : task.isFailed
                              ? AppTheme.errorRed
                              : AppTheme.warningOrange,
                    ),
                    const SizedBox(width: AppTheme.spaceXs),
                    Text(
                      task.isCompleted
                          ? 'Completed'
                          : task.isFailed
                              ? 'Failed'
                              : 'Pending',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: task.isCompleted
                            ? AppTheme.accentGreen
                            : task.isFailed
                                ? AppTheme.errorRed
                                : AppTheme.warningOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Text(
                _formatDateTime(task.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // Task Prompt
          Text(
            'Task Prompt',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            task.prompt,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),

          // Metrics
          const SizedBox(height: AppTheme.spaceLg),
          Row(
            children: [
              _buildMetric(
                icon: Icons.psychology_outlined,
                label: 'Thoughts',
                value: '${task.thoughts.length}',
                color: AppTheme.primaryPurple,
              ),
              const SizedBox(width: AppTheme.spaceMd),
              _buildMetric(
                icon: Icons.play_circle_outline_rounded,
                label: 'Actions',
                value: '${task.steps.length}',
                color: AppTheme.secondaryBlue,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppTheme.spaceSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMedium,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 18,
                color: AppTheme.warningOrange,
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: [
              _buildQuickActionChip(
                icon: Icons.replay_rounded,
                label: 'Re-run Task',
                color: AppTheme.secondaryBlue,
                onTap: () => _showRerunConfirmation(context),
              ),
              _buildQuickActionChip(
                icon: Icons.copy_rounded,
                label: 'Duplicate',
                color: AppTheme.primaryPurple,
                onTap: () => _duplicateTask(context),
              ),
              _buildQuickActionChip(
                icon: Icons.share_rounded,
                label: 'Share',
                color: AppTheme.accentGreen,
                onTap: () => _shareTask(context),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppTheme.spaceXs),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceSm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: AppTheme.spaceMd),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThoughtsList() {
    return Column(
      children: List.generate(
        task.thoughts.length,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: AppTheme.surfaceMedium,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.primaryPurple.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Text(
                  task.thoughts[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 300.ms, delay: (100 * index).ms)
            .slideX(begin: -0.1, end: 0),
      ),
    );
  }

  Widget _buildStepsList() {
    return Column(
      children: List.generate(
        task.steps.length,
        (index) {
          Map<String, dynamic> step = {};
          try {
            step = jsonDecode(task.steps[index]);
          } catch (e) {
            step = {'function': 'Unknown', 'args': {}};
          }

          return Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: AppTheme.surfaceMedium,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppTheme.secondaryBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryBlue.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondaryBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      child: Text(
                        step['function'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (step['timestamp'] != null)
                      Text(
                        _formatTime(DateTime.parse(step['timestamp'])),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                  ],
                ),
                if (step['args'] != null &&
                    (step['args'] as Map).isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceSm),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceSm),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      jsonEncode(step['args']),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 300.ms, delay: (100 * index).ms)
              .slideX(begin: -0.1, end: 0);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space2xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: AppTheme.textTertiary.withOpacity(0.5),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              'No execution data available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'This task hasn\'t been executed yet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.errorRed),
            const SizedBox(width: AppTheme.spaceMd),
            Text('Delete Task?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this task? This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final appState = Provider.of<AppState>(context, listen: false);
              appState.deleteTask(task.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close detail screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRerunConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Icon(Icons.replay_rounded, color: AppTheme.secondaryBlue),
            const SizedBox(width: AppTheme.spaceMd),
            Text('Re-run Task?'),
          ],
        ),
        content: Text(
          'This will execute the task again with the same prompt: "${task.prompt}"',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final appState = Provider.of<AppState>(context, listen: false);
              appState.rerunTask(task);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close detail screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Task re-run started'),
                  backgroundColor: AppTheme.secondaryBlue,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryBlue,
              foregroundColor: Colors.white,
            ),
            child: Text('Re-run'),
          ),
        ],
      ),
    );
  }

  void _duplicateTask(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.rerunTask(task);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task duplicated and started'),
        backgroundColor: AppTheme.primaryPurple,
      ),
    );
  }

  void _shareTask(BuildContext context) {
    // Simple share implementation - could be enhanced with actual sharing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share functionality - Coming soon!'),
        backgroundColor: AppTheme.accentGreen,
      ),
    );
  }

  String _formatDateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${time.day}/${time.month}/${time.year}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
