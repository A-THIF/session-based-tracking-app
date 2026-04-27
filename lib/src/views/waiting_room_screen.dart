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
import 'tracking_screen.dart';

class WaitingRoomScreen extends ConsumerWidget {
  const WaitingRoomScreen({super.key});

  void _cancel(BuildContext context, WidgetRef ref) {
    ref.read(sessionProvider.notifier).cancelSession();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final isHost = session.isHost;
    final code = session.session?.code ?? '------';
    final members = session.presentMembers;
    final hasPeer = members.isNotEmpty;

    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (next.status == SessionStatus.tracking) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TrackingScreen()),
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
                    onTap: () => _cancel(context, ref),
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
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF5AB9EA).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'SESSION CODE',
                      style: TextStyle(
                        color: Color(0xFF7A9BC0),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      code,
                      style: const TextStyle(
                        color: Color(0xFF5AB9EA),
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share this code with your friend',
                      style: TextStyle(color: Color(0xFF3D5A80), fontSize: 12),
                    ),
                  ],
                ),
              ),

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
                GestureDetector(
                  onTap: hasPeer
                      ? () => ref.read(sessionProvider.notifier).beginTracking()
                      : null,
                  child: AnimatedOpacity(
                    opacity: hasPeer ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: hasPeer
                            ? const Color(0xFF4ECDC4).withValues(alpha: 0.15)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasPeer
                              ? const Color(0xFF4ECDC4)
                              : const Color(0xFF1E3A5F),
                          width: 1.5,
                        ),
                        boxShadow: hasPeer
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF4ECDC4)
                                      .withValues(alpha: 0.2),
                                  blurRadius: 20,
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: hasPeer
                                ? const Color(0xFF4ECDC4)
                                : const Color(0xFF3D5A80),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasPeer ? 'START TRACKING' : 'WAITING FOR PEER…',
                            style: TextStyle(
                              color: hasPeer
                                  ? const Color(0xFF4ECDC4)
                                  : const Color(0xFF3D5A80),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
