import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

class CompassHudWidget extends StatelessWidget {
  final double distance;
  final String trackedName;
  final double targetBearing; // Bearing from Me to the other user
  final VoidCallback onBackToMap;

  const CompassHudWidget({
    Key? key,
    required this.distance,
    required this.trackedName,
    required this.targetBearing,
    required this.onBackToMap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85), // Blurred/Dark background
      child: Column(
        children: [
          const SizedBox(height: 60),
          // 1. Back Button
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                ),
                onPressed: onBackToMap,
                child: const Text(
                  'BACK TO MAP',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),

          // 2. Head Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white54),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              'HEAD ${distance.toStringAsFixed(0)}m',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const Spacer(),

          // 3. The 3D Rotating Arrow
          StreamBuilder<CompassEvent>(
            stream: FlutterCompass.events,
            builder: (context, snapshot) {
              double? direction = snapshot.data?.heading;
              if (direction == null) {
                return const Center(child: CircularProgressIndicator());
              }

              // Calculate how much to rotate the arrow
              // Relative Angle = Target Bearing - Current Phone Heading
              double relativeAngle =
                  (targetBearing - direction) * (math.pi / 180);

              return Transform.rotate(
                angle: relativeAngle,
                child: const Icon(
                  Icons.navigation_rounded,
                  size: 220,
                  color: Colors.white,
                ),
              );
            },
          ),

          const Spacer(),

          // 4. Proximity Message
          Text(
            '${trackedName.toUpperCase()} IS VERY CLOSE!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'HAPTIC FEEDBACK ACTIVE',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
