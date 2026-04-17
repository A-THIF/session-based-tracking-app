import 'package:flutter/material.dart';

class StatusAlertDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const StatusAlertDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF132036),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: Colors.white)),
        ],
      ),
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onRetry();
          },
          child: const Text('RETRY'),
        ),
      ],
    );
  }
}