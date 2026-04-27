// lib/src/widgets/tracking_header_widget.dart
//
// Top overlay bar on TrackingScreen.
// Dark blue theme matching the rest of the app.
// Format: TRACKING: [PEER_NAME] ([DISTANCE])

import 'package:flutter/material.dart';

class TrackingHeaderWidget extends StatelessWidget {
  final String trackedName;
  final String distance;

  const TrackingHeaderWidget({
    super.key,
    required this.trackedName,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.navigation_rounded,
                color: Color(0xFF4ECDC4),
                size: 16,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    children: [
                      const TextSpan(
                        text: 'TRACKING: ',
                        style: TextStyle(color: Color(0xFF7A9BC0)),
                      ),
                      TextSpan(
                        text: trackedName.toUpperCase(),
                        style: const TextStyle(color: Color(0xFF5AB9EA)),
                      ),
                      TextSpan(
                        text: '  $distance',
                        style: const TextStyle(
                          color: Color(0xFF4ECDC4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
