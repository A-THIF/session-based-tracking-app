// lib/src/widgets/tracking/navigation_pointer.dart
//
// NavigationPuck — map marker widget for Trace.
//
// Self  : Teal directional arrow/chevron, rotates with GPS heading,
//         initial letter inside, animated accuracy halo.
// Peer  : Teardrop pin with initial, direction tail rotates with their
//         heading, name label floats above.
//         States → active (orange) / high-speed (brighter) / timeout (red).

import 'dart:math' as math;
import 'package:flutter/material.dart';

enum PuckType { self, peer }

// Speed thresholds
const double _kHighSpeedKmh = 30.0;
const double _kIdleSpeedKmh = 2.0;

class NavigationPuck extends StatefulWidget {
  final PuckType type;

  /// Display name — shown as floating label above peer pin, and used
  /// to derive the initial letter shown inside both pointers.
  final String label;

  /// Compass bearing in degrees (0 = North, 90 = East …).
  final double bearing;

  /// Whether the peer's last packet has timed out.
  final bool isTimeout;

  /// Current speed in km/h — used to pick the visual state.
  /// For [PuckType.self] this drives the halo pulse rate.
  /// For [PuckType.peer] this drives the pin brightness.
  final double speedKmh;

  const NavigationPuck({
    super.key,
    required this.type,
    required this.label,
    this.bearing = 0,
    this.isTimeout = false,
    this.speedKmh = 0,
  });

  @override
  State<NavigationPuck> createState() => _NavigationPuckState();
}

class _NavigationPuckState extends State<NavigationPuck>
    with SingleTickerProviderStateMixin {
  late AnimationController _haloController;
  late Animation<double> _haloAnim;

  @override
  void initState() {
    super.initState();
    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _haloAnim = Tween<double>(begin: 0.08, end: 0.22).animate(
      CurvedAnimation(parent: _haloController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _haloController.dispose();
    super.dispose();
  }

  String get _initial =>
      widget.label.isNotEmpty ? widget.label[0].toUpperCase() : '?';

  // ── Color helpers ──────────────────────────────────────────────────────────

  Color get _baseColor {
    if (widget.type == PuckType.self) return const Color(0xFF4ECDC4);
    if (widget.isTimeout) return const Color(0xFFE05252);
    return widget.speedKmh >= _kHighSpeedKmh
        ? const Color(0xFFFFAA55) // brighter for high speed
        : const Color(0xFFFF8C42);
  }

  Color get _darkBg => const Color(0xFF0F172A);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return widget.type == PuckType.self ? _buildSelfPuck() : _buildPeerPuck();
  }

  // ── Self: teal directional arrow ──────────────────────────────────────────

  Widget _buildSelfPuck() {
    final color = _baseColor;
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated accuracy halo
          AnimatedBuilder(
            animation: _haloAnim,
            builder: (_, __) => Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: _haloAnim.value),
              ),
            ),
          ),

          // Static outer ring
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
          ),

          // Rotating arrow + inner circle
          Transform.rotate(
            angle: widget.bearing * math.pi / 180,
            child: CustomPaint(
              size: const Size(48, 48),
              painter: _SelfArrowPainter(color: color, initial: _initial),
            ),
          ),
        ],
      ),
    );
  }

  // ── Peer: teardrop pin ────────────────────────────────────────────────────

  Widget _buildPeerPuck() {
    final color = _baseColor;
    // Total height: name label (18) + gap (4) + pin body (48) + tail (14) = 84
    // We size the widget at 80×100 and let the stack handle overflow.
    return SizedBox(
      width: 80,
      height: 100,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // ── Floating name label ──────────────────────────────────────
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),

          // ── Pin body + tail (painted together) ───────────────────────
          Positioned(
            top: 22,
            child: AnimatedBuilder(
              animation: _haloAnim,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Soft pulse halo behind pin
                  if (!widget.isTimeout)
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: _haloAnim.value * 0.7),
                      ),
                    ),

                  // Teardrop pin shape
                  CustomPaint(
                    size: const Size(52, 68),
                    painter: _PeerPinPainter(
                      color: color,
                      darkBg: _darkBg,
                      initial: _initial,
                      isTimeout: widget.isTimeout,
                    ),
                  ),

                  // Direction tail — rotates with peer heading
                  // Positioned at the bottom-center of the pin
                  Positioned(
                    bottom: -10,
                    child: Transform.rotate(
                      angle: widget.bearing * math.pi / 180,
                      child: CustomPaint(
                        size: const Size(16, 16),
                        painter: _TailPainter(color: color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Painters ───────────────────────────────────────────────────────────

/// Draws the self-pointer: a chevron/arrow with a filled circle + initial.
class _SelfArrowPainter extends CustomPainter {
  final Color color;
  final String initial;

  const _SelfArrowPainter({required this.color, required this.initial});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final fillPaint = Paint()..color = color;
    final bgPaint = Paint()..color = const Color(0xFF0F172A);

    // Arrow / chevron pointing UP (North at 0°)
    final arrowPath = Path()
      ..moveTo(cx, cy - 22) // tip
      ..lineTo(cx - 14, cy + 10) // bottom-left
      ..lineTo(cx, cy + 4) // inner-bottom
      ..lineTo(cx + 14, cy + 10) // bottom-right
      ..close();

    canvas.drawPath(arrowPath, fillPaint);

    // Inner dark circle
    canvas.drawCircle(Offset(cx, cy + 1), 9, bgPaint);

    // Initial letter
    final tp = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 1 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SelfArrowPainter old) =>
      old.color != color || old.initial != initial;
}

/// Draws the peer pin: teardrop shape with initial inside.
class _PeerPinPainter extends CustomPainter {
  final Color color;
  final Color darkBg;
  final String initial;
  final bool isTimeout;

  const _PeerPinPainter({
    required this.color,
    required this.darkBg,
    required this.initial,
    required this.isTimeout,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final circleRadius = size.width * 0.44;
    final circleCy = circleRadius + 2;

    // Outer ring (dashed style for timeout via stroke)
    final borderPaint = Paint()
      ..color = color
      ..style = isTimeout ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = 2.5;

    // Teardrop = circle + triangle tail
    // Circle part
    final circlePaint = Paint()..color = color;
    canvas.drawCircle(Offset(cx, circleCy), circleRadius, circlePaint);

    // Tail triangle pointing down
    final tailPath = Path()
      ..moveTo(cx - 6, circleCy + circleRadius - 4)
      ..lineTo(cx + 6, circleCy + circleRadius - 4)
      ..lineTo(cx, size.height - 4)
      ..close();
    canvas.drawPath(tailPath, circlePaint);

    if (isTimeout) {
      // Draw dashed border ring for timeout state
      canvas.drawCircle(Offset(cx, circleCy), circleRadius, borderPaint);
    }

    // Inner dark circle
    final innerPaint = Paint()..color = darkBg;
    canvas.drawCircle(Offset(cx, circleCy), circleRadius * 0.72, innerPaint);

    // Initial letter
    final tp = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, circleCy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_PeerPinPainter old) =>
      old.color != color ||
      old.initial != initial ||
      old.isTimeout != isTimeout;
}

/// Small directional tail arrow that rotates to show peer heading.
class _TailPainter extends CustomPainter {
  final Color color;
  const _TailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..color = color;

    // Small equilateral triangle pointing UP (0° = North)
    final path = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx - 6, size.height)
      ..lineTo(cx + 6, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}
