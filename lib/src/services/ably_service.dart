// lib/src/services/ably_service.dart

import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

class AblyService {
  final ApiService _apiService = ApiService();
  ably.Realtime? _realtime;
  ably.RealtimeChannel? _channel;

  bool get isInitialized => _channel != null && _realtime != null;

  String? clientId;
  String? _initializedSessionCode;

  // ── Init ────────────────────────────────────────────────────────────────

  Future<void> initAbly(String sessionCode, String deviceId) async {
    // Guard: skip if already initialized for the same session + device
    if (_channel != null &&
        clientId == deviceId &&
        _initializedSessionCode == sessionCode) {
      debugPrint(
        '[AblyService] Already initialized for $deviceId on $sessionCode, skipping.',
      );
      return;
    }

    // Dispose old connection before re-initializing
    if (_realtime != null) {
      debugPrint('[AblyService] Disposing old connection before re-init.');
      _realtime!.close();
      _realtime = null;
      _channel = null;
      clientId = null;
      _initializedSessionCode = null;
    }

    try {
      final tokenMap = await _apiService.getAblyToken(sessionCode);
      final String? tokenString = tokenMap['token'] as String?;

      if (tokenString == null) throw Exception('Ably token is null from API');

      clientId = deviceId;
      _initializedSessionCode = sessionCode;

      final opts = ably.ClientOptions();
      opts.clientId = deviceId;

      // Bootstrap with the token we just fetched so the first connect is
      // immediate. The authCallback takes over for all subsequent renewals —
      // this prevents the silent 1-hour expiry disconnection (Fix 1.1).
      opts.tokenDetails = ably.TokenDetails(tokenString);
      opts.authCallback = (ably.TokenParams params) async {
        debugPrint('[AblyService] Token renewal triggered — fetching new token');
        final refreshed = await _apiService.getAblyToken(sessionCode);
        final newToken = refreshed['token'] as String?;
        if (newToken == null) throw Exception('Token refresh returned null');
        return ably.TokenDetails(newToken);
      };

      _realtime = ably.Realtime(options: opts);
      await _realtime!.connect();

      _channel = _realtime!.channels.get('session_$sessionCode');

      debugPrint(
        '[AblyService] Connected as $deviceId on session_$sessionCode',
      );
    } catch (e) {
      debugPrint('[AblyService] Init failed: $e');
      rethrow;
    }
  }

  // ── Location ─────────────────────────────────────────────────────────────

  void publishLocation(
    String deviceId,
    double lat,
    double lng, {
    double heading = 0,
    double speed = 0, // ADD
  }) {
    _channel!.publish(
      name: 'location_update',
      data: {
        'lat': lat,
        'lng': lng,
        'deviceId': deviceId,
        'heading': heading,
        'speed': speed, // ADD
      },
    );
  }

  Stream<ably.Message> getLocationStream() {
    if (_realtime == null || _channel == null) {
      debugPrint('[AblyService] Stream requested but channel not ready.');
      return const Stream.empty();
    }
    return _channel!.subscribe();
  }

  // ── Session state ─────────────────────────────────────────────────────────

  void publishSessionStarted() {
    _channel?.publish(name: 'session_state', data: {'state': 'started'});
  }

  void publishSessionEnded({String reason = 'host_ended'}) {
    _channel?.publish(
      name: 'session_state',
      data: {'state': 'ended', 'reason': reason},
    );
  }

  Future<bool> hasSessionStarted() async {
    final history = await getChannelHistory(limit: 1);
    if (history.items.isEmpty) return false;
    final msg = history.items.first;
    final data = msg.data as Map?;
    return msg.name == 'session_state' && data?['state'] == 'started';
  }
  void publishSpotlight(bool isOn) {
    if (_channel == null) return;
    _channel!.publish(
      name: 'spotlight',
      data: {'active': isOn},
    );
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

  /// Detaches all channel subscriptions without closing the Realtime
  /// connection. Call this from [LiveTrackingNotifier._dispose] so that a
  /// notifier rebuild doesn't leave orphaned listeners on the channel that
  /// would cause duplicate message processing (Fix 2.1).
  void disposeStreams() {
    try {
      _channel?.detach();
    } catch (_) {
      // best-effort — channel may already be detached
    }
  }

  void dispose() {
    _realtime?.close();
    _realtime = null;
    _channel = null;
    clientId = null;
    _initializedSessionCode = null;
  }
}

final ablyServiceProvider = Provider<AblyService>((ref) {
  final service = AblyService();
  ref.onDispose(() => service.dispose());
  return service;
});
