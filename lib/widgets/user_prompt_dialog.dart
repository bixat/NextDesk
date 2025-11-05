import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// A reusable dialog widget that prompts the user for input during automation
class UserPromptDialog extends StatefulWidget {
  final String question;

  const UserPromptDialog({
    super.key,
    required this.question,
  });

  /// Shows the dialog and returns the user's response
  static Future<String> show(BuildContext context, String question) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UserPromptDialog(question: question),
    );
    return result ?? 'cancel';
  }

  @override
  State<UserPromptDialog> createState() => _UserPromptDialogState();
}

class _UserPromptDialogState extends State<UserPromptDialog> {
  final _responseController = TextEditingController();

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  void _submitResponse() {
    final response = _responseController.text.trim();
    if (response.isNotEmpty) {
      Navigator.of(context).pop(response);
    }
  }

  void _cancel() {
    Navigator.of(context).pop('cancel');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: AppTheme.borderMedium, width: 2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceXs),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              color: AppTheme.primaryPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          const Expanded(
            child: Text(
              'Agent Needs Your Input',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question container
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: AppTheme.surfaceMedium,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Text(
              widget.question,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          
          // Label
          const Text(
            'Your response:',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          
          // Text field
          TextField(
            controller: _responseController,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.send,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Type your response here...',
              hintStyle: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppTheme.surfaceMedium,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.borderMedium),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.borderMedium),
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
                vertical: AppTheme.spaceSm,
              ),
            ),
            onSubmitted: (_) => _submitResponse(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textTertiary),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _submitResponse,
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Reply'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMd,
              vertical: AppTheme.spaceSm,
            ),
          ),
        ),
      ],
    );
  }
}

