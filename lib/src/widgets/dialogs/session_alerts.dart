import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/session_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../theme/trace_colors.dart';

// ── Shared dialog style helpers ───────────────────────────────────────────────

AlertDialog _styledDialog({
  required String title,
  required String content,
  required List<Widget> actions,
}) {
  return AlertDialog(
    backgroundColor: const Color(0xFF1E293B),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(
      title,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
    ),
    content: Text(
      content,
      style: const TextStyle(color: Color(0xFF7A9BC0), fontSize: 13),
    ),
    actions: actions,
  );
}

// ── Host: confirm they want to kill the room ──────────────────────────────────

Future<void> showConfirmEndDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _styledDialog(
      title: 'End Session?',
      content: 'This will terminate the tracking session for both users.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: TraceColors.neonTeal),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'End Session',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await ref.read(sessionProvider.notifier).cancelSession();
    if (context.mounted) {
      ref.invalidate(liveTrackingProvider); // sweep stale GPS cache
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

// ── Guest: notified that the host killed the room ─────────────────────────────

Future<void> showHostEndedDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _styledDialog(
      title: 'Session Ended',
      content: 'The host has ended this tracking session.',
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await ref.read(sessionProvider.notifier).cancelSession();
            if (context.mounted) {
              ref.invalidate(liveTrackingProvider); // sweep stale GPS cache
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          child: const Text(
            'OK',
            style: TextStyle(color: TraceColors.neonTeal),
          ),
        ),
      ],
    ),
  );
}

// ── Guest: confirm they want to quietly leave ─────────────────────────────────

Future<void> showConfirmLeaveDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _styledDialog(
      title: 'Leave Session?',
      content:
          'You will disconnect from the session. The host can continue tracking.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Stay',
            style: TextStyle(color: TraceColors.neonTeal),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Leave',
            style: TextStyle(
              color: Color(0xFFFFB74D),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await ref.read(sessionProvider.notifier).leaveSession();
    if (context.mounted) {
      ref.invalidate(liveTrackingProvider); // sweep stale GPS cache
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
