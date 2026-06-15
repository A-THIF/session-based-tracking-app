import 'package:flutter/material.dart';
import '../../theme/trace_colors.dart';

/// A full-screen radial gradient container that slowly breathes between
/// a bright neon-teal center and deep-teal edges.
///
/// The animation loops infinitely: forward → reverse → forward …
class SpotlightRadialGlow extends StatefulWidget {
  /// Optional child rendered on top of the gradient.
  final Widget? child;

  const SpotlightRadialGlow({super.key, this.child});

  @override
  State<SpotlightRadialGlow> createState() => _SpotlightRadialGlowState();
}

class _SpotlightRadialGlowState extends State<SpotlightRadialGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _controller.forward();
        }
      });

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: _pulseAnim.value,
              colors: const [
                TraceColors.neonTeal,
                TraceColors.deepTeal,
              ],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
