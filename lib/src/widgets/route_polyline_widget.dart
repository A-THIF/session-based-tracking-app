import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/trace_colors.dart';

class RouteLineWidget extends StatelessWidget {
  final List<LatLng> routePoints;

  const RouteLineWidget({super.key, required this.routePoints});

  @override
  Widget build(BuildContext context) {
    if (routePoints.isEmpty) return const SizedBox.shrink();

    return PolylineLayer(
      polylines: [
        // Layer 1 — Base Neon Glow (bottom)
        Polyline(
          points: routePoints,
          color: TraceColors.neonTeal.withValues(alpha: 0.2),
          strokeWidth: 12.0,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
        // Layer 2 — Outer Highlight Rim (middle)
        Polyline(
          points: routePoints,
          color: TraceColors.neonTeal.withValues(alpha: 0.5),
          strokeWidth: 7.0,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
        // Layer 3 — Inner Solid Core (top)
        Polyline(
          points: routePoints,
          color: TraceColors.neonTeal,
          strokeWidth: 3.5,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      ],
    );
  }
}
