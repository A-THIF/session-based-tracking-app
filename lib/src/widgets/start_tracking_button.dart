import 'package:flutter/material.dart';

class StartTrackingButton extends StatelessWidget {
  final bool hasPeer;
  final VoidCallback? onTap;

  const StartTrackingButton({
    super.key,
    required this.hasPeer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: hasPeer ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: hasPeer
                ? const Color(0xFF4ECDC4).withValues(alpha: 0.15)
                : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasPeer
                  ? const Color(0xFF4ECDC4)
                  : const Color(0xFF1E3A5F),
              width: 1.5,
            ),
            boxShadow: hasPeer
                ? [
                    BoxShadow(
                      color: const Color(0xFF4ECDC4).withValues(alpha: 0.2),
                      blurRadius: 20,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                color: hasPeer
                    ? const Color(0xFF4ECDC4)
                    : const Color(0xFF3D5A80),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                hasPeer ? 'START TRACKING' : 'WAITING FOR PEER…',
                style: TextStyle(
                  color: hasPeer
                      ? const Color(0xFF4ECDC4)
                      : const Color(0xFF3D5A80),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
