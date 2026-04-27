// lib/src/providers/tracking_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/ably_service.dart';
import 'session_provider.dart';

const int _kPacketTimeoutMs = 7000;

// ── Data class ────────────────────────────────────────────────────────────────

class TrackingData {
  final LatLng? myPos;
  final LatLng? peerPos;
  final List<LatLng> myPath;
  final List<LatLng> peerPath;
  final String distanceLabel;
  final String etaLabel;
  final bool isPeerTimeout;

  const TrackingData({
    this.myPos,
    this.peerPos,
    this.myPath = const [],
    this.peerPath = const [],
    this.distanceLabel = '—',
    this.etaLabel = '—',
    this.isPeerTimeout = false,
  });

  TrackingData copyWith({
    LatLng? myPos,
    LatLng? peerPos,
    List<LatLng>? myPath,
    List<LatLng>? peerPath,
    String? distanceLabel,
    String? etaLabel,
    bool? isPeerTimeout,
  }) {
    return TrackingData(
      myPos: myPos ?? this.myPos,
      peerPos: peerPos ?? this.peerPos,
      myPath: myPath ?? this.myPath,
      peerPath: peerPath ?? this.peerPath,
      distanceLabel: distanceLabel ?? this.distanceLabel,
      etaLabel: etaLabel ?? this.etaLabel,
      isPeerTimeout: isPeerTimeout ?? this.isPeerTimeout,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class LiveTrackingNotifier extends AsyncNotifier<TrackingData> {
  StreamSubscription<Position>? _gpsSub;
  StreamSubscription? _ablySub;
  Timer? _watchdog;
  bool _started = false; // 🔥 guard against double-build

  DateTime _lastPeerPacket = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<TrackingData> build() async {
    ref.onDispose(_dispose);

    // 🔥 Use read() — not watch() — so presence list updates don't rebuild this
    final session = ref.read(sessionProvider);

    if (session.status != SessionStatus.tracking ||
        session.deviceId == null ||
        session.session == null) {
      return const TrackingData();
    }

    // 🔥 Guard: only start once per provider lifetime
    if (_started) {
      print('[LiveTracking] Already started, skipping duplicate build.');
      return state.valueOrNull ?? const TrackingData();
    }
    _started = true;

    final ablyService = ref.read(ablyServiceProvider);

    // Wait for Ably to be ready (initialized by SessionNotifier)
    int retry = 0;
    while (!ablyService.isInitialized && retry < 20) {
      await Future.delayed(const Duration(milliseconds: 300));
      retry++;
    }

    if (!ablyService.isInitialized) {
      print('[LiveTracking] Ably never initialized after ${retry * 300}ms');
      return const TrackingData();
    }

    print('[LiveTracking] Ably ready, starting tracking...');

    final myDeviceId = session.deviceId!;
    final sessionCode = session.session!.code;
    final initialPaths = await _loadHistory(sessionCode);

    _startGpsPublisher(ablyService, myDeviceId);
    _startPeerListener(ablyService, myDeviceId);
    _startWatchdog(sessionCode);

    return TrackingData(myPath: initialPaths.$1, peerPath: initialPaths.$2);
  }

  // ── 1. GPS publisher ──────────────────────────────────────────────────────

  void _startGpsPublisher(AblyService ablyService, String myDeviceId) {
    _gpsSub =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.best,
            intervalDuration: const Duration(seconds: 3),
            distanceFilter: 0,
          ),
        ).listen((pos) {
          final me = LatLng(pos.latitude, pos.longitude);

          ablyService.publishLocation(myDeviceId, pos.latitude, pos.longitude);

          final current = state.valueOrNull ?? const TrackingData();

          state = AsyncData(_recalc(current.copyWith(myPos: me)));
        });
  }

  // ── 2. Peer listener ──────────────────────────────────────────────────────

  void _startPeerListener(AblyService ablyService, String myDeviceId) {
    print('[LiveTracking] Starting peer listener, my ID = $myDeviceId');

    _ablySub = ablyService.getLocationStream().listen(
      (msg) {
        if (msg.name != 'location_update' || msg.data == null) return;

        final raw = Map<String, dynamic>.from(msg.data as Map);
        final senderId = (raw['deviceId'] ?? '').toString();

        // 🚫 Remove echo
        if (senderId == myDeviceId) return;

        final peer = LatLng(
          (raw['lat'] as num).toDouble(),
          (raw['lng'] as num).toDouble(),
        );

        _lastPeerPacket = DateTime.now();

        final current = state.valueOrNull ?? const TrackingData();

        state = AsyncData(
          _recalc(current.copyWith(peerPos: peer, isPeerTimeout: false)),
        );
      },
      onError: (err) {
        print('[PeerListener] Stream error: $err');
      },
    );
  }

  // ── 3. Watchdog ───────────────────────────────────────────────────────────

  void _startWatchdog(String sessionCode) {
    _watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      final current = state.valueOrNull;
      if (current == null || current.peerPos == null) return;

      final ageMs = DateTime.now().difference(_lastPeerPacket).inMilliseconds;

      if (ageMs > _kPacketTimeoutMs && !current.isPeerTimeout) {
        print(
          '{"type":"location-timeout","session":"$sessionCode","ageMs":$ageMs}',
        );
        state = AsyncData(current.copyWith(isPeerTimeout: true));
      }
    });
  }

  // ── Distance + ETA ────────────────────────────────────────────────────────

  TrackingData _recalc(TrackingData data) {
    if (data.myPos == null || data.peerPos == null) return data;

    final dist = Geolocator.distanceBetween(
      data.myPos!.latitude,
      data.myPos!.longitude,
      data.peerPos!.latitude,
      data.peerPos!.longitude,
    );

    final etaSec = (dist / 1.4).round();

    final distLabel = dist >= 1000
        ? '${(dist / 1000).toStringAsFixed(2)} km'
        : '${dist.toStringAsFixed(0)} m';

    final etaLabel = etaSec > 60
        ? '${etaSec ~/ 60}m ${etaSec % 60}s'
        : '${etaSec}s';

    return data.copyWith(distanceLabel: distLabel, etaLabel: etaLabel);
  }

  // ── History seed ──────────────────────────────────────────────────────────

  Future<(List<LatLng>, List<LatLng>)> _loadHistory(String code) async {
    try {
      final details = await ref
          .read(sessionProvider.notifier)
          .loadSessionDetails(code);
      final List<dynamic> path = details['path'] ?? [];
      final myPath = path
          .map(
            (c) => LatLng(
              (c['latitude'] as num).toDouble(),
              (c['longitude'] as num).toDouble(),
            ),
          )
          .toList();
      return (myPath, <LatLng>[]);
    } catch (_) {
      return (<LatLng>[], <LatLng>[]);
    }
  }

  void _dispose() {
    _gpsSub?.cancel();
    _ablySub?.cancel();
    _watchdog?.cancel();
    _started = false;
  }
}

final liveTrackingProvider =
    AsyncNotifierProvider<LiveTrackingNotifier, TrackingData>(
      LiveTrackingNotifier.new,
    );
