import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AblyService {
  final ApiService _apiService = ApiService();
  ably.Realtime? _realtime;
  ably.RealtimeChannel? _channel;

  // Initialize and Connect
  Future<void> initAbly(String sessionCode) async {
    final tokenMap = await _apiService.getAblyToken(sessionCode);

    // Create the options
    final clientOptions = ably.ClientOptions();
    // We use the authCallback or tokenDetails to handle the map
    clientOptions.tokenDetails = ably.TokenDetails.fromMap(tokenMap);

    _realtime = ably.Realtime(options: clientOptions);
    _channel = _realtime!.channels.get('session_$sessionCode');
    await _realtime!.connect();
  }

  // Publish Location (Used by User A)
  void publishLocation(String deviceId, double lat, double lng) {
    _channel?.publish(
      name: 'location_update',
      data: {'lat': lat, 'lng': lng, 'deviceId': deviceId},
    );
  }

  void subscribeToPresence(Function(ably.PresenceMessage) callback) {
    _channel?.presence.subscribe().listen((presenceMessage) {
      callback(presenceMessage);
    });
  }

  // Subscribe to Location (Used by User B)
  Stream<ably.Message> getLocationStream() {
    return _channel!.subscribe();
  }

  void dispose() {
    _realtime?.close();
  }
}

final ablyServiceProvider = Provider<AblyService>((ref) {
  return AblyService();
});
