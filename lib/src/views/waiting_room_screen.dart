// lib/src/views/waiting_room_screen.dart
//
// Community 2 (Waiting): pure observer — zero Ably init here.
// SessionNotifier is the sole owner of the connection.
// Presence widgets live in lib/src/widgets/presence_status_widgets.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../widgets/radar_animation_widget.dart';
import '../widgets/presence_status_widgets.dart';
import '../widgets/session_code_card.dart';
import '../widgets/start_tracking_button.dart';
import 'tracking_screen.dart';

class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  bool _hasNavigated = false;

  Future<void> _cancel(BuildContext context) async {
    await ref.read(sessionProvider.notifier).cancelSession();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isHost = session.isHost;
    final code = session.session?.code ?? '------';
    final members = session.presentMembers;
    final hasPeer = members.isNotEmpty;

    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (next.status == SessionStatus.tracking) {
        if (!_hasNavigated) {
          _hasNavigated = true;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TrackingScreen()),
          );
        }
      } else if (next.status == SessionStatus.terminated) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Session Ended',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: const Text(
              'The host has ended this tracking session.',
              style: TextStyle(color: Color(0xFF7A9BC0), fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx); // dismiss dialog first
                  await ref.read(sessionProvider.notifier).cancelSession();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF4ECDC4)),
                ),
              ),
            ],
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top bar ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'WAITING ROOM',
                    style: TextStyle(
                      color: Color(0xFF7A9BC0),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _cancel(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded,
                              color: Colors.redAccent, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'CANCEL',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Session code card ──────────────────────────────────────
              SessionCodeCard(code: code),

              const SizedBox(height: 28),

              // ── Radar animation ────────────────────────────────────────
              const SizedBox(height: 180, child: RadarAnimationWidget()),

              const SizedBox(height: 28),

              // ── Presence status (extracted widgets) ────────────────────
              if (isHost)
                HostMemberSection(members: members)
              else
                GuestStatusSection(members: members),

              const SizedBox(height: 28),

              // ── Host: START TRACKING button ────────────────────────────
              if (isHost)
                StartTrackingButton(
                  hasPeer: hasPeer,
                  onTap: hasPeer
                      ? () => ref.read(sessionProvider.notifier).beginTracking()
                      : null,
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
