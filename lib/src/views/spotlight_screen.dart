// lib/src/widgets/spotlight_screen.dart
//
// Full-screen spotlight overlay — activated when user wants to be visible
// in a crowd. Screen fills with user's identity color and pulses.
//
// Haptic feedback frequency scales with distance:
//   > 25m  → no haptic
//   10–25m → slow pulse every 3s
//   5–10m  → medium pulse every 1.5s
//   < 5m   → rapid buzz every 0.5s

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SpotlightScreen extends StatefulWidget {
  /// The user's display name shown in the center circle.
  final String username;

  /// Identity color — teal for self, orange for peer.
  final Color color;

  /// Current distance to peer in meters — drives haptic frequency.
  final double distanceMeters;

  /// Whether this is showing YOUR spotlight (shows "Cancel")
  /// or the PEER's spotlight (shows "Found you!").
  final bool isSelf;

  final VoidCallback onCancel;
  final VoidCallback onFoundYou;

  const SpotlightScreen({
    super.key,
    required this.username,
    required this.color,
    required this.distanceMeters,
    required this.isSelf,
    required this.onCancel,
    required this.onFoundYou,
  });

  @override
  State<SpotlightScreen> createState() => _SpotlightScreenState();
}

class _SpotlightScreenState extends State<SpotlightScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _ringController;
  late Animation<double> _ringAnim;

  Timer? _hapticTimer;
  double _lastDistance = 0;

  @override
  void initState() {
    super.initState();

    // Main pulse — the background brightness breathes
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ring expand animation
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _ringAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ringController, curve: Curves.easeOut));

    _lastDistance = widget.distanceMeters;
    _startHapticTimer();
  }

  @override
  void didUpdateWidget(covariant SpotlightScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.distanceMeters != _lastDistance) {
      _lastDistance = widget.distanceMeters;
      _restartHapticTimer();
    }
  }

  void _startHapticTimer() {
    _hapticTimer?.cancel();
    final interval = _hapticInterval(widget.distanceMeters);
    if (interval == null) return;

    _hapticTimer = Timer.periodic(interval, (_) {
      if (widget.distanceMeters < 5) {
        HapticFeedback.heavyImpact();
      } else if (widget.distanceMeters < 10) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    });
  }

  void _restartHapticTimer() {
    _hapticTimer?.cancel();
    _startHapticTimer();
  }

  Duration? _hapticInterval(double dist) {
    if (dist > 25) return null;
    if (dist > 10) return const Duration(seconds: 3);
    if (dist > 5) return const Duration(milliseconds: 1500);
    return const Duration(milliseconds: 500);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    _hapticTimer?.cancel();
    super.dispose();
  }

  String get _initial =>
      widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?';

  // Darker version of the color for text on colored background
  Color get _darkColor {
    final hsl = HSLColor.fromColor(widget.color);
    return hsl.withLightness((hsl.lightness - 0.4).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _ringAnim]),
      builder: (context, _) {
        return Container(
          color: widget.color.withValues(alpha: _pulseAnim.value),
          child: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Expanding ring ────────────────────────────────────
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: _ringAnim.value,
                      color: Colors.white,
                    ),
                  ),
                ),

                // ── Second ring offset ────────────────────────────────
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: (_ringAnim.value + 0.4) % 1.0,
                      color: Colors.white,
                    ),
                  ),
                ),

                // ── Center content ────────────────────────────────────
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Avatar circle
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.25),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7),
                          width: 2.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _initial,
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Username
                    Text(
                      widget.username,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Hint text
                    Text(
                      widget.isSelf
                          ? 'look for the ${_colorName(widget.color)} screen'
                          : '${widget.username} is spotlighting',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),

                    // Distance if close
                    if (widget.distanceMeters <= 25) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.distanceMeters.toStringAsFixed(0)} m away',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // ── Bottom buttons ────────────────────────────────────
                Positioned(
                  bottom: 40,
                  left: 32,
                  right: 32,
                  child: widget.isSelf
                      ? _buildCancelButton()
                      : _buildFoundYouButton(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: widget.onCancel,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: const Center(
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFoundYouButton() {
    return GestureDetector(
      onTap: widget.onFoundYou,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            '✓  Found you!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _darkColor,
            ),
          ),
        ),
      ),
    );
  }

  String _colorName(Color color) {
    // Simple hue-based name
    final hsl = HSLColor.fromColor(color);
    final hue = hsl.hue;
    if (hue >= 160 && hue <= 200) return 'teal';
    if (hue >= 20 && hue <= 45) return 'orange';
    return 'colored';
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.7;
    final radius = maxRadius * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.35;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
