import 'dart:convert';
import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';
import '../services/ably_service.dart';

enum SessionStatus { idle, loading, waiting, tracking, error }

class SessionState {
  final Session? session;
  final SessionStatus status;
  final String? deviceId;
  final bool isHost;
  final String? errorMessage;
  final List<String> presentMembers;

  const SessionState({
    this.session,
    this.status = SessionStatus.idle,
    this.deviceId,
    this.isHost = false,
    this.errorMessage,
    this.presentMembers = const [],
  });

  SessionState copyWith({
    Session? session,
    SessionStatus? status,
    String? deviceId,
    bool? isHost,
    String? errorMessage,
    List<String>? presentMembers,
  }) {
    return SessionState(
      session: session ?? this.session,
      status: status ?? this.status,
      deviceId: deviceId ?? this.deviceId,
      isHost: isHost ?? this.isHost,
      errorMessage: errorMessage ?? this.errorMessage,
      presentMembers: presentMembers ?? this.presentMembers,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  final ApiService _api;
  final Ref _ref;

  SessionNotifier(this._api, this._ref) : super(const SessionState());

  String _normalizeDeviceId(String id) => id.trim().toLowerCase();

  // Get UUID from storage — this is now the deviceId
  // Replace _getUuid() with:
  Future<String> _getUuid() async {
    return await _api.getDeviceId();
  }

  // Get username for presence display
  Future<String> _getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('user_profile');
    if (stored == null) return 'unknown';
    try {
      final json = jsonDecode(stored);
      return json['username'] as String? ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  // ── Community 1: Home actions ────────────────────────────────────────────

  Future<void> startNewSession() async {
    state = state.copyWith(status: SessionStatus.loading);
    try {
      final id = await _getUuid(); // ← UUID now, not device model
      final data = await _api.createSession(60);
      final session = Session(code: data['sessionCode'] as String);

      state = state.copyWith(
        session: session,
        deviceId: id,
        status: SessionStatus.waiting,
        isHost: true,
      );
      await _initAbly(session.code, id);
    } catch (e) {
      _api.sendRemoteLog("SESSION_CREATE_FAIL", "N/A", e.toString());
      state = state.copyWith(
        status: SessionStatus.error,
        errorMessage: _friendlyError(e.toString()),
      );
    }
  }

  Future<void> joinSession(String code) async {
    state = state.copyWith(status: SessionStatus.loading);
    try {
      final id = await _getUuid(); // ← UUID now, not device model
      final session = await _api.joinSession(code, id);

      state = state.copyWith(
        session: session,
        deviceId: id,
        status: SessionStatus.waiting,
        isHost: false,
      );
      await _initAbly(code, id);
    } catch (e) {
      state = state.copyWith(
        status: SessionStatus.error,
        errorMessage: _friendlyError(e.toString()),
      );
    }
  }

  // ── Community 2: Sole owner of Ably init ─────────────────────────────────

  Future<void> _initAbly(String code, String deviceId) async {
    final ablyService = _ref.read(ablyServiceProvider);

    await ablyService.initAbly(code, deviceId);

    final displayName = await _getDisplayName();
    await ablyService.enterPresence(displayName);

    // Fix: single clean block, no duplicate variable
    final existingMembers = await ablyService.getPresentMembers();
    if (mounted) {
      state = state.copyWith(
        presentMembers: existingMembers
            .where(
              (m) =>
                  _normalizeDeviceId(m.clientId ?? '') !=
                  _normalizeDeviceId(deviceId),
            )
            .map((m) => m.data?.toString() ?? m.clientId ?? 'Unknown')
            .toList(),
      );
    }

    ablyService.subscribeToPresence((msg) async {
      if (!mounted) return;
      final name = msg.data?.toString() ?? msg.clientId ?? 'Unknown';
      final clientId = msg.clientId ?? '';

      if (_normalizeDeviceId(clientId) == _normalizeDeviceId(deviceId)) return;

      if (msg.action == ably.PresenceAction.enter ||
          msg.action == ably.PresenceAction.present) {
        final current = List<String>.from(state.presentMembers);
        if (!current.any(
          (m) => _normalizeDeviceId(m) == _normalizeDeviceId(name),
        )) {
          current.add(name);
          state = state.copyWith(presentMembers: current);
        }
      } else if (msg.action == ably.PresenceAction.leave) {
        state = state.copyWith(
          presentMembers: List<String>.from(state.presentMembers)
            ..removeWhere(
              (m) => _normalizeDeviceId(m) == _normalizeDeviceId(name),
            ),
        );
      }
    });

    ablyService.subscribeToChannelMessages().listen((message) {
      if (!mounted) return;
      final data = message.data as Map?;
      if (message.name == 'session_state' && data?['state'] == 'started') {
        state = state.copyWith(status: SessionStatus.tracking);
      }
    });
  }

  // ── Community 2 → 3 transition ───────────────────────────────────────────

  void beginTracking() {
    _ref.read(ablyServiceProvider).publishSessionStarted();
    state = state.copyWith(status: SessionStatus.tracking);
  }

  // ── Cancel / leave session ────────────────────────────────────────────────

  void cancelSession() {
    _ref.read(ablyServiceProvider).dispose();
    state = const SessionState();
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> loadSessionDetails(String code) {
    return _api.getSessionDetails(code);
  }

  String _friendlyError(String raw) {
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'No internet connection. Check your Wi-Fi or data.';
    }
    if (raw.contains('TimeoutException')) {
      return 'Server is waking up. Please try again in 10 seconds.';
    }
    if (raw.contains('404') || raw.contains('Invalid session')) {
      return 'Session code not found. Check the code and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((
  ref,
) {
  return SessionNotifier(ApiService(), ref);
});
