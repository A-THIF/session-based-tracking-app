// lib/src/widgets/presence_status_widgets.dart
//
// Presence status panels for WaitingRoomScreen.
//   HostMemberSection  — member list with green checkmarks + READY badges
//   GuestStatusSection — "Connected. Waiting for [host]…" with host tile

import 'package:flutter/material.dart';

// ── HostMemberSection ─────────────────────────────────────────────────────────

class HostMemberSection extends StatelessWidget {
  final List<String> members;

  const HostMemberSection({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header count ───────────────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.people_alt_rounded,
                color: Color(0xFF7A9BC0),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                members.isEmpty
                    ? 'No one has joined yet'
                    : '${members.length} peer${members.length > 1 ? 's' : ''} connected',
                style: const TextStyle(
                  color: Color(0xFF7A9BC0),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // ── Member rows ────────────────────────────────────────────────
          if (members.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF1E3A5F), height: 1),
            const SizedBox(height: 14),
            ...members.map(
              (name) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    // Green checkmark avatar
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF00E676),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // READY badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'READY',
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── GuestStatusSection ────────────────────────────────────────────────────────

class GuestStatusSection extends StatelessWidget {
  /// Other members visible to the guest — first entry is treated as the host.
  final List<String> members;

  const GuestStatusSection({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    final hostName = members.isNotEmpty ? members.first : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4ECDC4).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Connected pill ─────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Connected.',
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Status message ─────────────────────────────────────────────
          Text(
            hostName != null
                ? 'Waiting for $hostName to start tracking…'
                : 'Waiting for the Host to start tracking…',
            style: const TextStyle(
              color: Color(0xFF7A9BC0),
              fontSize: 13,
              height: 1.5,
            ),
          ),

          // ── Host tile ──────────────────────────────────────────────────
          if (hostName != null) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF1E3A5F), height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5AB9EA).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF5AB9EA),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hostName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // HOST badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5AB9EA).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'HOST',
                    style: TextStyle(
                      color: Color(0xFF5AB9EA),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
