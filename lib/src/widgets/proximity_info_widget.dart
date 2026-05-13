import 'package:flutter/material.dart';

class ProximityInfoWidget extends StatelessWidget {
  final String distance;
  final String eta;
  final String myName;
  final String peerName;
  final bool peerConnected;
  final double mySpeed; // 🟢 Add this
  final double peerSpeed; // 🟢 Add this
  // ── Spotlight ──────────────────────────────────────────────────
  final bool isSpotlightActive;
  final VoidCallback onSpotlightToggle;

  const ProximityInfoWidget({
    super.key,
    required this.distance,
    required this.eta,
    required this.myName,
    required this.peerName,
    required this.mySpeed, // 🟢 Add this
    required this.peerSpeed, // 🟢 Add this
    required this.isSpotlightActive,
    required this.onSpotlightToggle,
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
            // Connection pill — just status, no legend item
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
                Text(
                  peerConnected
                      ? '$peerName is live'
                      : '$peerName — no signal (>7s)',
                  style: TextStyle(
                    color: peerConnected
                        ? const Color(0xFF00E676)
                        : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
          // ── Legend ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _LegendItem(
                  color: const Color(0xFF4ECDC4),
                  label: myName,
                  speed:
                      mySpeed, // 🟢 This ensures the speed badge shows your speed
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: _LegendItem(
                  color: const Color(0xFFFF8C42),
                  label: peerName,
                  speed:
                      peerSpeed, // 🟢 This ensures the speed badge shows peer speed
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF1E3A5F), height: 1),
          const SizedBox(height: 12),

          // ── Spotlight row ─────────────────────────────────────────
          _SpotlightRow(
            peerName: peerName,
            isActive: isSpotlightActive,
            onToggle: onSpotlightToggle,
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
  final double speed; // 🟢 Add speed

  const _LegendItem({
    required this.color,
    required this.label,
    required this.speed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            "$label • ${speed.toStringAsFixed(0)} km/h", // 🟢 Shows: Naf • 34 km/h
            style: const TextStyle(color: Color(0xFF7A9BC0), fontSize: 12),
          ),
        ),
      ],
    );
  }
}
// ── Spotlight row ─────────────────────────────────────────────

class _SpotlightRow extends StatelessWidget {
  final String peerName;
  final bool isActive;
  final VoidCallback onToggle;

  const _SpotlightRow({
    required this.peerName,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: label + description
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SPOTLIGHT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isActive
                    ? 'Your screen is visible to $peerName'
                    : 'Help $peerName find you in a crowd',
                style: const TextStyle(color: Color(0xFF7A9BC0), fontSize: 11),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Right: toggle button
        GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.redAccent.withValues(alpha: 0.15)
                  : const Color(0xFF4ECDC4),
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.5),
                      width: 0.8,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.close_rounded : Icons.wb_sunny_rounded,
                  size: 16,
                  color: isActive ? Colors.redAccent : const Color(0xFF0F172A),
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? 'TURN OFF' : 'TURN ON',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isActive
                        ? Colors.redAccent
                        : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
