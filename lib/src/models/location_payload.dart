import 'package:latlong2/latlong.dart'; // ✅ Changed from google_maps_flutter

class LocationPayload {
  const LocationPayload({
    required this.deviceId,
    required this.position,
    required this.timestamp,
  });

  final String deviceId;
  final LatLng position; // This now uses the latlong2 version
  final DateTime timestamp;

  factory LocationPayload.fromJson(Map<String, dynamic> json) {
    // 1. Handle different key names from backend/Ably
    final dynamic rawLat = json['lat'] ?? json['latitude'];
    final dynamic rawLng = json['lng'] ?? json['longitude'];
    final dynamic rawTimestamp = json['timestamp'];

    return LocationPayload(
      // 2. Ensure deviceId is never null
      deviceId: (json['deviceId'] ?? json['device_id'] ?? 'unknown').toString(),

      // 3. Create the OSM-compatible LatLng
      position: LatLng(
        (rawLat as num?)?.toDouble() ?? 0.0,
        (rawLng as num?)?.toDouble() ?? 0.0,
      ),

      // 4. Robust timestamp parsing
      timestamp: _parseDateTime(rawTimestamp),
    );
  }

  static DateTime _parseDateTime(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }
    if (timestamp is int) {
      // Handles Unix timestamps if your backend sends them
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return DateTime.now();
  }
}
