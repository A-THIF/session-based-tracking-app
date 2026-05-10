// lib/src/services/routing_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/constants.dart'; // <--- ADD THIS LINE

/// Road route response model
class RoadRoute {
  final List<LatLng> points;  
  final double distanceMeters;
  final int durationSeconds;

  const RoadRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class RoutingService {
  /// Fetches road-snapped route from backend
  Future<RoadRoute> getWaterfallRoute(LatLng start, LatLng end) async {
    final url = Uri.parse('${AppConfig.baseUrl}/session/route/path').replace(
      queryParameters: {
        'startLat': start.latitude.toString(),
        'startLng': start.longitude.toString(),
        'endLat': end.latitude.toString(),
        'endLng': end.longitude.toString(),
      },
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final List<dynamic> pointsRaw = data['points'];

        final points = pointsRaw
            .map(
              (p) => LatLng(
                (p['latitude'] as num).toDouble(),
                (p['longitude'] as num).toDouble(),
              ),
            )
            .toList();

        return RoadRoute(
          points: points,
          distanceMeters: (data['distanceMeters'] as num?)?.toDouble() ?? 0,
          durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (e) {
      print("Routing error: $e");
    }

    // fallback
    return RoadRoute(
      points: [start, end],
      distanceMeters: 0,
      durationSeconds: 0,
    );
  }
}
