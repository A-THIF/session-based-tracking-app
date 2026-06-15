import 'package:flutter/material.dart';

class SessionCodeCard extends StatelessWidget {
  final String code;

  const SessionCodeCard({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
