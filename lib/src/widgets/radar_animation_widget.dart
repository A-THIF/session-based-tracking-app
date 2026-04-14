import 'package:flutter/material.dart';

class RadarAnimationWidget extends StatefulWidget {
  const RadarAnimationWidget({Key? key}) : super(key: key);

  @override
  State<RadarAnimationWidget> createState() => _RadarAnimationWidgetState();
}

class _RadarAnimationWidgetState extends State<RadarAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Controls the speed of the sweep
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Central Pulse Center
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFF5AB9EA),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.blueAccent, blurRadius: 10)],
          ),
        ),

        // 2. Animated growing rings
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: RadarPainter(_controller.value),
              child: const SizedBox(
                width: double.infinity,
                height: double.infinity,
              ),
            );
          },
        ),
      ],
    );
  }
}

// Custom Painter to draw the radar lines
class RadarPainter extends CustomPainter {
  final double animationValue;
  RadarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    var paintLine = Paint()
      ..color = const Color(0xFF5AB9EA).withOpacity(1.0 - animationValue)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    var paintSolid = Paint()
      ..color = const Color(0xFF5AB9EA)
          .withOpacity((1.0 - animationValue).clamp(0.0, 0.3)) // Fading effect
      ..style = PaintingStyle.fill;

    double maxRadius = size.width * 0.4;
    double currentRadius = animationValue * maxRadius;

    Offset center = Offset(size.width / 2, size.height / 2);

    // Draw solid fading circle
    canvas.drawCircle(center, currentRadius, paintSolid);

    // Draw the main expanding ring
    canvas.drawCircle(center, currentRadius, paintLine);

    // Optionally draw background rings (as seen in mockup)
    canvas.drawCircle(
      center,
      maxRadius * 0.3,
      Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      center,
      maxRadius * 0.6,
      Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      center,
      maxRadius * 0.9,
      Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
