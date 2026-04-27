import 'package:flutter/material.dart';

class ProximityInfoWidget extends StatelessWidget {
  final String distance;
  final String eta;
  final String myName;
  final String peerName;
  final bool peerConnected;

  const ProximityInfoWidget({
    super.key,
    required this.distance,
    required this.eta,
    required this.myName,
    required this.peerName,
    this.peerConnected = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: peerConnected
              ? const Color(0xFF1E3A5F)
              : Colors.redAccent.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Connection pill ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: peerConnected
                  ? const Color(0xFF00C853).withValues(alpha: 0.15)
                  : Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: peerConnected
                        ? const Color(0xFF00E676)
                        : Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    peerConnected
                        ? '$peerName is live'
                        : '$peerName — no signal (>7s)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: peerConnected
                          ? const Color(0xFF00E676)
                          : Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFF1E3A5F), height: 1),
          const SizedBox(height: 14),

          // ── Distance + ETA ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.place_rounded,
                  accent: const Color(0xFF4ECDC4),
                  label: 'Distance',
                  value: distance,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: const Color(0xFF1E3A5F),
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              Expanded(
                child: _StatCell(
                  icon: Icons.timer_rounded,
                  accent: const Color(0xFFFFB74D),
                  label: 'ETA (walking)',
                  value: eta,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFF1E3A5F), height: 1),
          const SizedBox(height: 10),

          // ── Legend ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _LegendItem(
                  color: const Color(0xFF4ECDC4),
                  label: myName,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: _LegendItem(
                  color: const Color(0xFFFF8C42),
                  label: peerName,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String label;
  final String value;

  const _StatCell({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: accent, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7A9BC0),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF7A9BC0),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
