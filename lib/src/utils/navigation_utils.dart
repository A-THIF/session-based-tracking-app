import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class NavigationUtils {
  /// Calculates the bearing from [start] to [end] in degrees (0-360).
  static double calculateBearing(LatLng start, LatLng end) {
    final double startLat = _degreesToRadians(start.latitude);
    final double startLng = _degreesToRadians(start.longitude);
    final double endLat = _degreesToRadians(end.latitude);
    final double endLng = _degreesToRadians(end.longitude);

    final double dLng = endLng - startLng;

    final double y = math.sin(dLng) * math.cos(endLat);
    final double x =
        math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    final double bearing = math.atan2(y, x);
    return (_radiansToDegrees(bearing) + 360) % 360;
  }

  static double _degreesToRadians(double degrees) => degrees * (math.pi / 180);
  static double _radiansToDegrees(double radians) => radians * (180 / math.pi);
}
