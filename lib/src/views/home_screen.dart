// lib/src/views/home_screen.dart
//
// Community 1 (Home): delegates all logic to SessionNotifier.
// Widget classes live in lib/src/widgets/session_cards.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../widgets/permission_guard.dart';
import '../widgets/session_cards.dart';
import 'waiting_room_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onStartSession() async {
    final hasPermission = await PermissionGuard.checkSettings(context);
    if (!hasPermission || !mounted) return;
    ref.read(sessionProvider.notifier).startNewSession();
  }

  Future<void> _onJoinSession() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 6-character code')),
      );
      return;
    }
    final hasPermission = await PermissionGuard.checkSettings(context);
    if (!hasPermission || !mounted) return;
    ref.read(sessionProvider.notifier).joinSession(code);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isLoading = session.status == SessionStatus.loading;

    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (next.status == SessionStatus.waiting && next.session != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WaitingRoomScreen()),
        );
      }
      if (next.status == SessionStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E3A5F),
            content: Text(
              next.errorMessage!,
              style: const TextStyle(color: Colors.redAccent),
            ),
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
              const SizedBox(height: 24),

              // ── Logo / Title ───────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5AB9EA).withValues(alpha: 0.3),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.radar,
                        color: Color(0xFF5AB9EA),
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'TRACE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Real-time session tracking',
                      style: TextStyle(
                        color: Color(0xFF7A9BC0),
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 56),

              // ── START SESSION card ─────────────────────────────────────
              ActionCard(
                icon: Icons.add_location_alt_rounded,
                iconColor: const Color(0xFF4ECDC4),
                accentColor: const Color(0xFF4ECDC4),
                title: 'Start a Session',
                subtitle: 'Create a new tracking session\nand share the code',
                onTap: isLoading ? null : _onStartSession,
                isLoading: isLoading,
              ),

              const SizedBox(height: 16),

              // ── JOIN SESSION card ──────────────────────────────────────
              JoinCard(
                controller: _codeController,
                onJoin: isLoading ? null : _onJoinSession,
                isLoading: isLoading,
              ),

              const SizedBox(height: 40),

              // ── Footer ─────────────────────────────────────────────────
              const Center(
                child: Text(
                  'Both users must be on the same session code',
                  style: TextStyle(color: Color(0xFF3D5A80), fontSize: 12),
                  textAlign: TextAlign.center,
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
