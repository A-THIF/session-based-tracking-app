import 'package:flutter/material.dart';

/// Bottom stats card showing live distance + ETA between both users.
///
/// Fully driven by parameters — no hardcoded values.
/// Drop into [TrackingScreen] inside an [Align] or [Positioned] widget.
class StatsBottomCardWidget extends StatelessWidget {
  /// Formatted distance string, e.g. "320 m" or "1.24 km"
  final String distance;

  /// Formatted ETA string, e.g. "4 min" or "< 1 min"
  final String eta;

  /// Display name of the current user
  final String myName;

  /// Display name of the peer
  final String peerName;

  /// Whether the peer is currently sending location packets
  final bool peerConnected;

  const StatsBottomCardWidget({
    Key? key,
    required this.distance,
    required this.eta,
    required this.myName,
    required this.peerName,
    required this.peerConnected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Peer status pill ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: peerConnected
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFF5252),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                peerConnected ? '$peerName is live' : '$peerName disconnected',
                style: TextStyle(
                  color: peerConnected
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFF5252),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFF1E3050), height: 1),
          const SizedBox(height: 14),

          // ── Distance + ETA row ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.straighten_rounded,
                  iconColor: const Color(0xFF5AB9EA),
                  label: 'Distance',
                  value: distance,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: const Color(0xFF1E3050),
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: _StatTile(
                  icon: Icons.timer_outlined,
                  iconColor: const Color(0xFFFFB74D),
                  label: 'ETA (walking)',
                  value: eta,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Legend ─────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: const Color(0xFF2196F3), label: myName),
              const SizedBox(width: 20),
              _LegendDot(color: const Color(0xFFFF6D00), label: peerName),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7A9BC0),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7A9BC0),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
