import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

/// Single-channel session design:
///   channel = 'session_{code}'
///   Every message has [clientId] baked in by Ably (set during [initAbly]).
///   No separate host/guest channels — clientId IS the identity.
class AblyService {
  final ApiService _apiService = ApiService();
  ably.Realtime? _realtime;
  ably.RealtimeChannel? _channel;

  bool get isInitialized => _channel != null;

  /// The clientId this instance was initialized with.
  /// Exposed so TrackingScreen can filter out its own echoes.
  String? clientId;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> initAbly(String sessionCode, String deviceId) async {
    try {
      final tokenMap = await _apiService.getAblyToken(sessionCode);
      final String? tokenString = tokenMap['token'] as String?;

      if (tokenString == null) throw Exception('Ably token is null from API');

      clientId = deviceId;

      final opts = ably.ClientOptions();
      opts.tokenDetails = ably.TokenDetails(tokenString);
      opts.clientId = deviceId;

      _realtime = ably.Realtime(options: opts);
      await _realtime!.connect();

      // ONE private channel for the whole session.
      _channel = _realtime!.channels.get('session_$sessionCode');

      print('[AblyService] Connected as $deviceId on session_$sessionCode');
    } catch (e) {
      print('[AblyService] Init failed: $e');
      rethrow;
    }
  }

  // ── Location ──────────────────────────────────────────────────────────────

  /// Publishes this device's GPS position to the session channel.
  /// Ably stamps the outgoing message with [clientId] automatically.
  void publishLocation(String deviceId, double lat, double lng) {
    if (_channel == null) {
      print('[AblyService] publishLocation: channel not ready');
      return;
    }
    _channel!.publish(
      name: 'location_update',
      data: {'lat': lat, 'lng': lng, 'deviceId': deviceId},
    );
  }

  /// Stream of ALL location_update messages on the session channel.
  /// Callers must filter out their own echoes using [clientId].
  Stream<ably.Message> getLocationStream() {
    if (_channel == null) {
      print('[AblyService] getLocationStream: channel not ready');
      return const Stream.empty();
    }
    return _channel!.subscribe();
  }

  // ── Session state ─────────────────────────────────────────────────────────

  void publishSessionStarted() {
    _channel?.publish(name: 'session_state', data: {'state': 'started'});
  }

  Future<bool> hasSessionStarted() async {
    final history = await getChannelHistory(limit: 1);
    if (history.items.isEmpty) return false;
    final msg = history.items.first;
    final data = msg.data as Map?;
    return msg.name == 'session_state' && data?['state'] == 'started';
  }

  // ── Presence ──────────────────────────────────────────────────────────────

  Future<void> enterPresence(String deviceName) async {
    await _channel?.presence.enter(deviceName);
  }

  void subscribeToPresence(Function(ably.PresenceMessage) callback) {
    _channel?.presence.subscribe().listen(callback);
  }

  Future<List<ably.PresenceMessage>> getPresentMembers() async {
    if (_channel == null) return [];
    return await _channel!.presence.get();
  }

  // ── Generic channel subscription ─────────────────────────────────────────

  Stream<ably.Message> subscribeToChannelMessages() {
    if (_channel == null) return const Stream.empty();
    return _channel!.subscribe();
  }

  Future<ably.PaginatedResult<ably.Message>> getChannelHistory({
    int limit = 1,
  }) async {
    if (_channel == null) throw Exception('Channel not ready');
    return await _channel!.history(ably.RealtimeHistoryParams(limit: limit));
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void dispose() {
    _realtime?.close();
  }
}

final ablyServiceProvider = Provider<AblyService>((ref) => AblyService());
