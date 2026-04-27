// lib/src/widgets/session_cards.dart
//
// Reusable cards for HomeScreen.
//   ActionCard  — large tappable card with icon, title, subtitle, arrow
//   JoinCard    — ActionCard variant with an embedded text field + join button

import 'package:flutter/material.dart';

// ── ActionCard ────────────────────────────────────────────────────────────────

class ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

  const ActionCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accentColor,
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 18),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF7A9BC0),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: accentColor.withValues(alpha: 0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── JoinCard ──────────────────────────────────────────────────────────────────

class JoinCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onJoin;
  final bool isLoading;

  const JoinCard({
    super.key,
    required this.controller,
    required this.onJoin,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF8C42).withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C42).withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C42).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: Color(0xFFFF8C42),
                  size: 28,
                ),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join a Session',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Enter the 6-character code\nshared by your friend',
                      style: TextStyle(
                        color: Color(0xFF7A9BC0),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Code input
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: '• • • • • •',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                letterSpacing: 8,
                fontSize: 18,
              ),
              counterText: '',
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFFF8C42),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Join button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: onJoin,
              child: AnimatedOpacity(
                opacity: onJoin == null ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C42).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF8C42).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF8C42),
                            ),
                          )
                        : const Text(
                            'JOIN SESSION',
                            style: TextStyle(
                              color: Color(0xFFFF8C42),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
