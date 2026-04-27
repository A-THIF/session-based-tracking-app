// lib/src/providers/session_provider.dart
//
// Community 1 (Home)  : startNewSession / joinSession → ApiService → waiting
// Community 2 (Waiting): sole owner of AblyService init, presence, and
//                        session_state:started listener

import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // ── Community 1: Home actions ────────────────────────────────────────────

  Future<void> startNewSession() async {
    state = state.copyWith(status: SessionStatus.loading);
    try {
      final id = await _api.getDeviceId();
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
      state = state.copyWith(
        status: SessionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> joinSession(String code) async {
    state = state.copyWith(status: SessionStatus.loading);
    try {
      final id = await _api.getDeviceId();
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
        errorMessage: e.toString(),
      );
    }
  }

  // ── Community 2: Sole owner of Ably init ─────────────────────────────────

  Future<void> _initAbly(String code, String deviceId) async {
    final ablyService = _ref.read(ablyServiceProvider);

    // deviceId IS the clientId — critical for echo filtering in Community 3
    await ablyService.initAbly(code, deviceId);
    await ablyService.enterPresence(deviceId);

    // Populate initial presence snapshot immediately
    final existing = await ablyService.getPresentMembers();
    if (mounted) {
      state = state.copyWith(
        presentMembers: existing
            .map((m) => m.clientId ?? 'Unknown')
            .where(
              (id) => _normalizeDeviceId(id) != _normalizeDeviceId(deviceId),
            )
            .toList(),
      );
    }

    // Live presence updates — enter/present adds, leave removes
    ablyService.subscribeToPresence((msg) async {
      if (!mounted) return;
      final name = msg.clientId ?? 'Unknown';

      // Never show ourselves in the list
      if (_normalizeDeviceId(name) == _normalizeDeviceId(deviceId)) return;

      if (msg.action == ably.PresenceAction.enter ||
          msg.action == ably.PresenceAction.present) {
        final current = List<String>.from(state.presentMembers);
        final alreadyPresent = current.any(
          (member) => _normalizeDeviceId(member) == _normalizeDeviceId(name),
        );
        if (!alreadyPresent) {
          current.add(name);
          state = state.copyWith(presentMembers: current);
        }
      } else if (msg.action == ably.PresenceAction.leave) {
        final current = List<String>.from(state.presentMembers)
          ..removeWhere(
            (member) =>
                _normalizeDeviceId(member) == _normalizeDeviceId(name),
          );
        state = state.copyWith(presentMembers: current);
      }
    });

    // Guest: listen for host's session_state:started signal
    ablyService.subscribeToChannelMessages().listen((message) {
      if (!mounted) return;
      final data = message.data as Map?;
      if (message.name == 'session_state' && data?['state'] == 'started') {
        state = state.copyWith(status: SessionStatus.tracking);
      }
    });
  }

  // ── Community 2 → 3 transition: host triggers this ───────────────────────

  void beginTracking() {
    _ref.read(ablyServiceProvider).publishSessionStarted();
    state = state.copyWith(status: SessionStatus.tracking);
  }

  // ── Cancel / leave session ────────────────────────────────────────────────

  void cancelSession() {
    _ref.read(ablyServiceProvider).dispose();
    state = const SessionState(); // reset to idle
  }

  // ── Utility: used by tracking_provider to seed breadcrumb history ─────────

  Future<Map<String, dynamic>> loadSessionDetails(String code) {
    return _api.getSessionDetails(code);
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(ApiService(), ref);
});
