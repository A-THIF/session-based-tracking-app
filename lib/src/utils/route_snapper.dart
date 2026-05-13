import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class RouteSnapper {
  /// Snaps a raw [point] to the nearest position on the [route].
  /// Returns the raw point if it's further than [thresholdMeters] away (the "leash").
  static LatLng snapToRoute(
    LatLng point,
    List<LatLng> route, {
    double thresholdMeters = 20.0,
  }) {
    if (route.isEmpty) return point;

    LatLng? closestPoint;
    double minDistance = double.infinity;

    // Iterate through all segments of the route
    for (int i = 0; i < route.length - 1; i++) {
      final p1 = route[i];
      final p2 = route[i + 1];

      final snapped = _findNearestPointOnSegment(point, p1, p2);
      final dist = Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        snapped.latitude,
        snapped.longitude,
      );

      if (dist < minDistance) {
        minDistance = dist;
        closestPoint = snapped;
      }
    }

    // Only return the snapped point if it's within the "leash" distance
    if (closestPoint != null && minDistance <= thresholdMeters) {
      return closestPoint;
    }

    return point; // User is off-route, return raw GPS
  }

  static LatLng _findNearestPointOnSegment(LatLng p, LatLng a, LatLng b) {
    double l2 =
        math_pow(a.latitude - b.latitude, 2) +
        math_pow(a.longitude - b.longitude, 2);
    if (l2 == 0) return a;

    double t =
        ((p.latitude - a.latitude) * (b.latitude - a.latitude) +
            (p.longitude - a.longitude) * (b.longitude - a.longitude)) /
        l2;

    t = t.clamp(0.0, 1.0);

    return LatLng(
      a.latitude + t * (b.latitude - a.latitude),
      a.longitude + t * (b.longitude - a.longitude),
    );
  }

  static double math_pow(double val, int exp) => val * val;
}
