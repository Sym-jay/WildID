// lib/shared/widgets/error_dialog.dart

import 'package:flutter/material.dart';

/// Reusable error dialog widget
class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ErrorDialog({
    super.key,
    this.title = 'Error',
    required this.message,
    this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onAction?.call();
            },
            child: Text(actionLabel!),
          ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onDismiss?.call();
          },
          child: const Text('Dismiss'),
        ),
      ],
    );
  }
}

/// Show error dialog helper
void showErrorDialog(
  BuildContext context, {
  required String message,
  String title = 'Error',
  VoidCallback? onDismiss,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => ErrorDialog(
      title: title,
      message: message,
      onDismiss: onDismiss,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}
