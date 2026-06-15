import 'dart:convert';
import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';
import '../services/ably_service.dart';

enum SessionStatus { idle, loading, waiting, tracking, error, terminated }

class SessionState {
  final Session? session;
  final SessionStatus status;
  final String? deviceId;
  final bool isHost;
  final String? errorMessage;
  final List<String> presentMembers;
  final String? username; // 🟢 Add this line

  const SessionState({
    this.session,
    this.status = SessionStatus.idle,
    this.deviceId,
    this.isHost = false,
    this.errorMessage,
    this.presentMembers = const [],
    this.username, // 🟢 Add this line
  });

  SessionState copyWith({
    Session? session,
    SessionStatus? status,
    String? deviceId,
    bool? isHost,
    String? errorMessage,
    List<String>? presentMembers,
    String? username, // 🟢 Add this parameter
  }) {
    return SessionState(
      session: session ?? this.session,
      status: status ?? this.status,
      deviceId: deviceId ?? this.deviceId,
      isHost: isHost ?? this.isHost,
      errorMessage: errorMessage ?? this.errorMessage,
      presentMembers: presentMembers ?? this.presentMembers,
      username: username ?? this.username, // 🟢 Add this line
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  final ApiService _api;
  final Ref _ref;
  bool _isProcessing = false; // guards against duplicate network calls

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

  // ── Session persistence (rejoin support) ─────────────────────────────────

  static const _kActiveSessionKey = 'active_session_code';

  Future<void> _saveActiveSession(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveSessionKey, code);
  }

  Future<void> _clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActiveSessionKey);
  }

  static Future<String?> readSavedSessionCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveSessionKey);
  }

  // ── Community 1: Home actions ────────────────────────────────────────────

  Future<void> startNewSession() async {
    if (_isProcessing) return;
    _isProcessing = true;
    state = state.copyWith(status: SessionStatus.loading);
    try {
      final id = await _getUuid();
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
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> joinSession(String code) async {
    if (_isProcessing) return;
    _isProcessing = true;
    state = state.copyWith(status: SessionStatus.loading);
    try {
      final id = await _getUuid();
      final session = await _api.joinSession(code, id);

      state = state.copyWith(
        session: session,
        deviceId: id,
        status: SessionStatus.waiting,
        isHost: false,
      );
      await _saveActiveSession(code);
      await _initAbly(code, id);
    } catch (e) {
      state = state.copyWith(
        status: SessionStatus.error,
        errorMessage: _friendlyError(e.toString()),
      );
    } finally {
      _isProcessing = false;
    }
  }

  // ── Community 2: Sole owner of Ably init ─────────────────────────────────

  Future<void> _initAbly(String code, String deviceId) async {
    final ablyService = _ref.read(ablyServiceProvider);

    await ablyService.initAbly(code, deviceId);

    // In both startNewSession() and joinSession(), after _initAbly:
    final displayName = await _getDisplayName();
    state = state.copyWith(username: displayName);
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
      if (message.name == 'session_state') {
        if (data?['state'] == 'started') {
          state = state.copyWith(status: SessionStatus.tracking);
        } else if (data?['state'] == 'ended' && !state.isHost) {
          // Only guests react to the remote kill signal.
          // Hosts triggered this themselves via cancelSession().
          _handleRemoteTermination();
        }
      }
    });
  }

  // ── Community 2 → 3 transition ───────────────────────────────────────────

  void beginTracking() {
    _ref.read(ablyServiceProvider).publishSessionStarted();
    state = state.copyWith(status: SessionStatus.tracking);
  }

  // ── Cancel / leave session ────────────────────────────────────────────────

  /// Host path: fires HTTP end + Ably broadcast before clearing local state.
  /// Guest path: just disposes Ably and resets state.
  Future<void> cancelSession() async {
    final sessionCode = state.session?.code;
    final wasHost = state.isHost;

    if (wasHost && sessionCode != null) {
      try {
        _ref.read(ablyServiceProvider).publishSessionEnded();
        await _api.endSession(sessionCode);
      } catch (e) {
        debugPrint('[Session] endSession HTTP failed: $e');
      }
    }

    _ref.read(ablyServiceProvider).dispose();
    await _clearActiveSession();
    state = const SessionState();
  }

  /// Guest path: quietly drops local connection without touching the backend.
  /// The session stays alive for the host.
  Future<void> leaveSession() async {
    await _clearActiveSession();
    _ref.read(ablyServiceProvider).dispose();
    state = const SessionState();
  }

  /// Crash-recovery rejoin: validates the room is still alive then pushes
  /// straight to tracking. Clears stored code if the room is gone.
  /// Returns true if rejoin succeeded so the UI can navigate.
  Future<bool> rejoinSession(String code) async {
    state = state.copyWith(status: SessionStatus.loading);
    try {
      final id = await _getUuid();
      final session = await _api.joinSession(code, id);

      state = state.copyWith(
        session: session,
        deviceId: id,
        status: SessionStatus.tracking,
        isHost: false,
      );
      await _initAbly(code, id);
      return true;
    } catch (e) {
      // Room is gone — clear stale key and drop back to idle.
      await _clearActiveSession();
      state = state.copyWith(
        status: SessionStatus.idle,
        errorMessage: _friendlyError(e.toString()),
      );
      return false;
    }
  }

  /// Called by the Ably listener when a guest receives 'ended' from the host.
  /// Sets status to [SessionStatus.terminated] so the UI can show a dialog
  /// before navigating away — keeps BuildContext out of this notifier.
  void _handleRemoteTermination() {
    _ref.read(ablyServiceProvider).dispose();
    state = state.copyWith(status: SessionStatus.terminated);
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
