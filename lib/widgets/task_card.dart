import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../config/app_theme.dart';
import '../screens/task_detail_screen.dart';
import '../providers/app_state.dart';

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMedium,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: task.isCompleted
              ? AppTheme.accentGreen.withOpacity(0.5)
              : task.isFailed
                  ? AppTheme.errorRed.withOpacity(0.5)
                  : AppTheme.borderMedium,
          width: task.isCompleted || task.isFailed ? 1.5 : 1,
        ),
        boxShadow: task.isCompleted || task.isFailed ? AppTheme.shadowSm : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskDetailScreen(task: task),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status icon with animation
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(AppTheme.spaceXs),
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? AppTheme.accentGreen.withOpacity(0.15)
                            : task.isFailed
                                ? AppTheme.errorRed.withOpacity(0.15)
                                : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        task.isCompleted
                            ? Icons.check_circle_rounded
                            : task.isFailed
                                ? Icons.error_rounded
                                : Icons.pending_rounded,
                        size: 20,
                        color: task.isCompleted
                            ? AppTheme.accentGreen
                            : task.isFailed
                                ? AppTheme.errorRed
                                : AppTheme.warningOrange,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      child: Text(
                        task.prompt,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Quick action buttons
                    _buildQuickActionButton(
                      context: context,
                      icon: Icons.replay_rounded,
                      color: AppTheme.secondaryBlue,
                      tooltip: 'Re-run',
                      onTap: () => _rerunTask(context),
                    ),
                    const SizedBox(width: AppTheme.spaceXs),
                    _buildQuickActionButton(
                      context: context,
                      icon: Icons.delete_outline_rounded,
                      color: AppTheme.errorRed,
                      tooltip: 'Delete',
                      onTap: () => _deleteTask(context),
                    ),
                  ],
                ),
                if (task.thoughts.isNotEmpty || task.steps.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  Row(
                    children: [
                      if (task.thoughts.isNotEmpty) ...[
                        _buildMetricChip(
                          icon: Icons.psychology_outlined,
                          label: '${task.thoughts.length}',
                          tooltip: 'Thoughts',
                          color: AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: AppTheme.spaceSm),
                      ],
                      if (task.steps.isNotEmpty) ...[
                        _buildMetricChip(
                          icon: Icons.play_circle_outline_rounded,
                          label: '${task.steps.length}',
                          tooltip: 'Actions',
                          color: AppTheme.secondaryBlue,
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: AppTheme.spaceSm),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: AppTheme.spaceXs),
                    Text(
                      _formatTime(task.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String tooltip,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSm,
          vertical: AppTheme.spaceXs,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppTheme.spaceXs),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
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

  Widget _buildQuickActionButton({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceXs),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }

  void _rerunTask(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
          'Execute this task again?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final appState = Provider.of<AppState>(context, listen: false);
              appState.rerunTask(task);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Task re-run started'),
                  backgroundColor: AppTheme.secondaryBlue,
                  behavior: SnackBarBehavior.floating,
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

  void _deleteTask(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
          'This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final appState = Provider.of<AppState>(context, listen: false);
              appState.deleteTask(task.id);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Task deleted'),
                  backgroundColor: AppTheme.errorRed,
                  behavior: SnackBarBehavior.floating,
                ),
              );
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
}
