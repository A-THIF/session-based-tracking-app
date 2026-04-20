import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AblyService {
  final ApiService _apiService = ApiService();
  ably.Realtime? _realtime;
  ably.RealtimeChannel? _channel;
  bool isInitialized = false;

  // Initialize and Connect
  Future<void> initAbly(String sessionCode, String clientId) async {
    try {
      final tokenMap = await _apiService.getAblyToken(sessionCode);
      final String? tokenString = tokenMap['token'] as String?;

      if (tokenString == null) {
        throw Exception("Ably Token is null from API");
      }

      final clientOptions = ably.ClientOptions();
      clientOptions.tokenDetails = ably.TokenDetails(tokenString);
      clientOptions.clientId =
          clientId; // CRITICAL: must match what backend signed

      _realtime = ably.Realtime(options: clientOptions);
      await _realtime!.connect();
      _channel = _realtime!.channels.get('session_$sessionCode');

      print("Ably Connected as: $clientId");
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
    _channel!.publish(
      name: 'location_update',
      data: {'lat': lat, 'lng': lng, 'deviceId': deviceId},
    );
  }

  void publishSessionStarted() {
    if (_channel == null) {
      print("Cannot publish: Ably channel not initialized");
      return;
    }

    _channel!.publish(name: 'session_state', data: {'state': 'started'});
  }

  Future<bool> hasSessionStarted() async {
    final history = await getChannelHistory(limit: 1);

    if (history.items.isEmpty) return false;

    final msg = history.items.first;
    final data = msg.data as Map?;

    return msg.name == 'session_state' && data?['state'] == 'started';
  }

  Stream<ably.Message> subscribeToChannelMessages() {
    if (_channel == null) {
      print("Warning: subscribeToChannelMessages called before channel ready.");
      return const Stream.empty();
    }
    return _channel!.subscribe();
  }

  void subscribeToPresence(Function(ably.PresenceMessage) callback) {
    _channel?.presence.subscribe().listen((presenceMessage) {
      callback(presenceMessage);
    });
  }

  Future<void> enterPresence(String deviceName) async {
    await _channel?.presence.enter(deviceName);
  }

  Future<ably.PaginatedResult<ably.Message>> getChannelHistory({
    int limit = 1,
  }) async {
    if (_channel == null) throw Exception("Channel not ready");

    return await _channel!.history(
      ably.RealtimeHistoryParams(limit: limit), // ✅ correct for latest SDK
    );
  }

  // Add this to get the initial list of people already in the room
  Future<List<ably.PresenceMessage>> getPresentMembers() async {
    if (_channel == null) return [];
    return await _channel!.presence.get();
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
