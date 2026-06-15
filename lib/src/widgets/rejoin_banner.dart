import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../theme/trace_colors.dart';
import '../views/tracking_screen.dart';

/// Persistent banner shown on HomeScreen when a saved session code is found
/// in local storage after a crash or backgrounding.
///
/// Tapping "Rejoin" re-validates the room with the backend and pushes to
/// TrackingScreen on success, or clears the stale key on failure.
class RejoinBanner extends ConsumerStatefulWidget {
  const RejoinBanner({super.key});

  @override
  ConsumerState<RejoinBanner> createState() => _RejoinBannerState();
}

class _RejoinBannerState extends ConsumerState<RejoinBanner> {
  String? _savedCode;
  bool _isLoading = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _checkForSavedSession();
  }

  Future<void> _checkForSavedSession() async {
    final code = await SessionNotifier.readSavedSessionCode();
    if (mounted && code != null) {
      setState(() => _savedCode = code);
    }
  }

  Future<void> _onRejoin() async {
    if (_savedCode == null) return;
    setState(() => _isLoading = true);

    final success =
        await ref.read(sessionProvider.notifier).rejoinSession(_savedCode!);

    if (!mounted) return;

    if (success) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TrackingScreen()),
      );
    } else {
      // Room is gone — hide the banner and show a brief message.
      setState(() {
        _dismissed = true;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That session is no longer active.'),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_savedCode == null || _dismissed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: TraceColors.neonTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TraceColors.neonTeal.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering_rounded,
              color: TraceColors.neonTeal, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You have an active tracking session.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TraceColors.neonTeal,
                  ),
                )
              : GestureDetector(
                  onTap: _onRejoin,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: TraceColors.neonTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Rejoin',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
          const SizedBox(width: 4),
          // Dismiss
          GestureDetector(
            onTap: () => setState(() => _dismissed = true),
            child: const Icon(Icons.close, color: Colors.white38, size: 18),
          ),
        ],
      ),
    );
  }
}
