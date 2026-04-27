import 'package:flutter/material.dart';

class RecenterFab extends StatelessWidget {
  final VoidCallback onTap;

  const RecenterFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF4ECDC4).withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.my_location_rounded,
          color: Color(0xFF4ECDC4),
          size: 20,
        ),
      ),
    );
  }
}
