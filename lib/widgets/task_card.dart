import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              task.completed ? Colors.green.withOpacity(0.3) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                task.completed ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: task.completed ? Colors.green : Colors.white54,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.prompt,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (task.thoughts.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              '${task.thoughts.length} thoughts • ${task.steps.length} actions',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
          SizedBox(height: 4),
          Text(
            _formatTime(task.createdAt),
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
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

