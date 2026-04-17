import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AblyService {
  final ApiService _apiService = ApiService();
  ably.Realtime? _realtime;
  ably.RealtimeChannel? _channel;
  bool isInitialized = false;

  // Initialize and Connect
  Future<void> initAbly(String sessionCode) async {
    try {
      final tokenMap = await _apiService.getAblyToken(sessionCode);
      final String? tokenString = tokenMap['token'] as String?;

      if (tokenString == null) {
        print("Error: Ably Token is null from API");
        return;
      }

      // Correct way for ably_flutter 1.2.44:
      // Create empty options, then assign tokenDetails using the string
      final clientOptions = ably.ClientOptions();
      clientOptions.tokenDetails = ably.TokenDetails(tokenString);

      _realtime = ably.Realtime(options: clientOptions);

      _realtime!.connection.on().listen((stateChange) {
        print('Ably Connection State: ${stateChange.current}');
      });

      await _realtime!.connect();

      _channel = _realtime!.channels.get('session_$sessionCode');
      print("Ably Connected successfully to session_$sessionCode");
    } catch (e) {
      print("Failed to initialize Ably: $e");
      rethrow;
    }
  }

  // Publish Location (Used by User A)
  void publishLocation(String deviceId, double lat, double lng) {
    if (_channel == null) {
      print("Cannot publish: Ably channel not initialized");
      return;
    }
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
  // FIXED: Return an empty stream if channel isn't ready instead of crashing
  Stream<ably.Message> getLocationStream() {
    if (_channel == null) {
      print("Warning: getLocationStream called before channel was ready.");
      return const Stream.empty();
    }
    return _channel!.subscribe();
  }

  void dispose() {
    _realtime?.close();
  }
}

final ablyServiceProvider = Provider<AblyService>((ref) {
  return AblyService();
});
