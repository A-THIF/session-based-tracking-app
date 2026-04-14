import 'package:flutter/material.dart';

class StatsBottomCardWidget extends StatelessWidget {
  final String distance;
  final String eta;

  const StatsBottomCardWidget({
    Key? key,
    required this.distance,
    required this.eta,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF5AB9EA), // Blue from mockup
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15)],
      ),
      child: Column(
        children: [
          Text(
            'DIST: $distance',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'ETA: $eta (WALKING)',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
