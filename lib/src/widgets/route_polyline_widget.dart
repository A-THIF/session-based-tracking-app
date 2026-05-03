import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RouteLineWidget extends StatelessWidget {
  final List<LatLng> routePoints;

  const RouteLineWidget({super.key, required this.routePoints});

  @override
Widget build(BuildContext context) {
  if (routePoints.isEmpty) return const SizedBox.shrink();

  return PolylineLayer(
    polylines: [
      // 1. THE OUTLINE (Draw this first)
      Polyline(
        points: routePoints,
        color: const Color(0xFF0F172A), // Dark outline color
        strokeWidth: 7.0, // Thicker
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ),
      // 2. THE MAIN LINE
      Polyline(
        points: routePoints,
        color: const Color(0xFF4ECDC4), // Main brand color
        strokeWidth: 4.0, // Thinner
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ),
    ],
  );
}}