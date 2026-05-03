// lib/src/services/routing_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/constants.dart';

class RoutingService {
  /// Fetches the road-snapped path from the Render backend.
  /// The backend handles the Stadia -> ORS waterfall logic.
  Future<List<LatLng>> getWaterfallRoute(LatLng start, LatLng end) async {
    final url = Uri.parse('${AppConfig.baseUrl}/session/route/path').replace(
      queryParameters: {
        'startLat': start.latitude.toString(),
        'startLng': start.longitude.toString(),
        'endLat': end.latitude.toString(),
        'endLng': end.longitude.toString(),
      },
    );

    try {
      // Use a timeout to handle Render "Cold Starts" gracefully
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> points = data['points'];

        return points
            .map(
              (p) => LatLng(
                (p['latitude'] as num).toDouble(),
                (p['longitude'] as num).toDouble(),
              ),
            )
            .toList();
      }
    } catch (e) {
      // If the backend fails, we log it locally for debugging
      print("Routing error: $e");
    }

    // Final fallback: Return a straight line between the two users
    return [start, end];
  }
}
