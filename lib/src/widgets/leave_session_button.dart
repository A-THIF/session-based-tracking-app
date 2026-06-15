import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dialogs/session_alerts.dart';

/// GUEST ONLY — confirms leave and disconnects without touching the server.
/// For host teardown, use [EndSessionButton].
class LeaveSessionButton extends ConsumerWidget {
  const LeaveSessionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => showConfirmLeaveDialog(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB74D).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFFB74D).withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.logout_rounded,
              color: Color(0xFFFFB74D),
              size: 16,
            ),
            SizedBox(width: 6),
            Text(
              'LEAVE',
              style: TextStyle(
                color: Color(0xFFFFB74D),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
