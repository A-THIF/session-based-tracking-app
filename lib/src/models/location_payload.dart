import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPayload {
  const LocationPayload({
    required this.deviceId,
    required this.position,
    required this.timestamp,
  });

  final String deviceId;
  final LatLng position;
  final DateTime timestamp;

  factory LocationPayload.fromJson(Map<String, dynamic> json) {
    final dynamic rawLat = json['lat'] ?? json['latitude'];
    final dynamic rawLng = json['lng'] ?? json['longitude'];
    final dynamic rawTimestamp = json['timestamp'];

    return LocationPayload(
      deviceId: (json['deviceId'] ?? json['device_id'] ?? 'unknown').toString(),
      position: LatLng(
        (rawLat as num?)?.toDouble() ?? 0,
        (rawLng as num?)?.toDouble() ?? 0,
      ),
      timestamp: rawTimestamp is String
          ? DateTime.tryParse(rawTimestamp) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
