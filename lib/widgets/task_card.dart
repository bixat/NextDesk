import 'package:flutter/material.dart';
import '../models/task.dart';
import '../config/app_theme.dart';

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
          color: task.completed
              ? AppTheme.accentGreen.withOpacity(0.5)
              : AppTheme.borderMedium,
          width: task.completed ? 1.5 : 1,
        ),
        boxShadow: task.completed ? AppTheme.shadowSm : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: () {
            // TODO: Show task details
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
                        color: task.completed
                            ? AppTheme.accentGreen.withOpacity(0.15)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        task.completed
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: task.completed
                            ? AppTheme.accentGreen
                            : AppTheme.textTertiary,
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
}
