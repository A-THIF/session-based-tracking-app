import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/trace_typography.dart';
import '../widgets/tracking/spotlight_radial_glow.dart';

/// Immersive Uber-style spotlight screen.
///
/// Uses [SpotlightRadialGlow] as the full-screen breathing gradient background.
/// Shows instructional text + prominent username identifier.
/// A single X button at the bottom dismisses the screen.
///
/// isSelf = true  → user holds up their phone to be found
/// isSelf = false → peer is spotlighting, user can confirm they found them
class SpotlightScreen extends StatefulWidget {
  final String username;
  final bool isSelf;
  final VoidCallback onCancel;
  final VoidCallback onFoundYou;

  // Legacy params kept for call-site compatibility — not rendered.
  final Color color;
  final double distanceMeters;

  const SpotlightScreen({
    super.key,
    required this.username,
    required this.isSelf,
    required this.onCancel,
    required this.onFoundYou,
    this.color = const Color(0xFF00D1B2),
    this.distanceMeters = 0,
  });

  @override
  State<SpotlightScreen> createState() => _SpotlightScreenState();
}

class _SpotlightScreenState extends State<SpotlightScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String get _instructionText => widget.isSelf
      ? 'When your peer is arriving, hold up\nyour phone so they can spot this color.'
      : '${widget.username} is spotlighting.\nLook for the teal screen.';

  @override
  Widget build(BuildContext context) {
    return SpotlightRadialGlow(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // ── Center content ──────────────────────────────────────
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Instructional text
                    Text(
                      _instructionText,
                      textAlign: TextAlign.center,
                      style: TraceTypography.bodyLarge.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Prominent identifier — "Ruben - Black Toyota Camry" style
                    Text(
                      widget.username,
                      textAlign: TextAlign.center,
                      style: TraceTypography.headlineMedium.copyWith(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom dismiss / confirm button ─────────────────────
            Positioned(
              bottom: 52,
              left: 0,
              right: 0,
              child: Center(
                child: widget.isSelf
                    ? _DismissButton(onTap: widget.onCancel)
                    : _FoundYouButton(onTap: widget.onFoundYou),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dismiss X button ──────────────────────────────────────────────────────────

class _DismissButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DismissButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

// ── Found You confirm button ──────────────────────────────────────────────────

class _FoundYouButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FoundYouButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Text(
          '✓  Found you!',
          style: TraceTypography.bodyLarge.copyWith(
            color: const Color(0xFF0A2E2A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
