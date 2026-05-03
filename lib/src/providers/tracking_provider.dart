// lib/src/providers/tracking_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/ably_service.dart';
import '../services/routing_service.dart';
import 'session_provider.dart';

const int _kPacketTimeoutMs = 7000;

class TrackingData {
  final LatLng? myPos;
  final LatLng? peerPos;
  final List<LatLng> myPath;
  final List<LatLng> peerPath;
  final List<LatLng> routePoints;
  final String distanceLabel;
  final String etaLabel;
  final bool isPeerTimeout;

  const TrackingData({
    this.myPos,
    this.peerPos,
    this.myPath = const [],
    this.peerPath = const [],
    this.routePoints = const [],
    this.distanceLabel = '—',
    this.etaLabel = '—',
    this.isPeerTimeout = false,
  });

  TrackingData copyWith({
    LatLng? myPos,
    LatLng? peerPos,
    List<LatLng>? myPath,
    List<LatLng>? peerPath,
    List<LatLng>? routePoints,
    String? distanceLabel,
    String? etaLabel,
    bool? isPeerTimeout,
  }) {
    return TrackingData(
      myPos: myPos ?? this.myPos,
      peerPos: peerPos ?? this.peerPos,
      myPath: myPath ?? this.myPath,
      peerPath: peerPath ?? this.peerPath,
      routePoints: routePoints ?? this.routePoints,
      distanceLabel: distanceLabel ?? this.distanceLabel,
      etaLabel: etaLabel ?? this.etaLabel,
      isPeerTimeout: isPeerTimeout ?? this.isPeerTimeout,
    );
  }
}

class LiveTrackingNotifier extends AsyncNotifier<TrackingData> {
  StreamSubscription<Position>? _gpsSub;
  StreamSubscription? _ablySub;
  Timer? _watchdog;
  bool _started = false;

  final RoutingService _routingService = RoutingService();

  DateTime? _lastRouteFetch;
  LatLng? _lastRoutePos;
  String? _currentSessionCode;
  DateTime _lastPeerPacket = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<TrackingData> build() async {
    ref.onDispose(_dispose);

    final session = ref.read(sessionProvider);

    if (session.status != SessionStatus.tracking ||
        session.deviceId == null ||
        session.session == null) {
      return const TrackingData();
    }

    if (_started) {
      debugPrint('[LiveTracking] Already started, skipping duplicate build.');
      return state.valueOrNull ?? const TrackingData();
    }

    _started = true;
    _currentSessionCode = session.session!.code;

    final ablyService = ref.read(ablyServiceProvider);

    int retry = 0;
    while (!ablyService.isInitialized && retry < 20) {
      await Future.delayed(const Duration(milliseconds: 300));
      retry++;
    }

    if (!ablyService.isInitialized) {
      debugPrint('[LiveTracking] Ably never initialized');
      return const TrackingData();
    }

    debugPrint('[LiveTracking] Ably ready, starting tracking...');

    final myDeviceId = session.deviceId!;
    final initialPaths = await _loadHistory(_currentSessionCode!);

    _startGpsPublisher(ablyService, myDeviceId);
    _startPeerListener(ablyService, myDeviceId);
    _startWatchdog(_currentSessionCode!);

    return TrackingData(myPath: initialPaths.$1, peerPath: initialPaths.$2);
  }

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

  void _startPeerListener(AblyService ablyService, String myDeviceId) {
    debugPrint('[LiveTracking] Starting peer listener');

    _ablySub = ablyService.getLocationStream().listen(
      (msg) {
        if (msg.name != 'location_update' || msg.data == null) return;

        final raw = Map<String, dynamic>.from(msg.data as Map);
        final senderId = (raw['deviceId'] ?? '').toString();

        if (senderId == myDeviceId) return;

        final peer = LatLng(
          (raw['lat'] as num).toDouble(),
          (raw['lng'] as num).toDouble(),
        );

        _lastPeerPacket = DateTime.now();

        final current = state.valueOrNull ?? const TrackingData();

        if (_currentSessionCode != null) {
          _maybeUpdateRoute(current.myPos, peer);
        }

        state = AsyncData(
          _recalc(current.copyWith(peerPos: peer, isPeerTimeout: false)),
        );

        debugPrint('[LiveTracking] Peer updated: $senderId');
      },
      onError: (err) {
        debugPrint('[PeerListener] Stream error: $err');
      },
    );
  }

  void _startWatchdog(String sessionCode) {
    _watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      final current = state.valueOrNull;

      if (current == null || current.peerPos == null) return;

      final ageMs = DateTime.now().difference(_lastPeerPacket).inMilliseconds;

      if (ageMs > _kPacketTimeoutMs && !current.isPeerTimeout) {
        debugPrint(
          '{"type":"location-timeout","session":"$sessionCode","ageMs":$ageMs}',
        );

        state = AsyncData(current.copyWith(isPeerTimeout: true));
      }
    });
  }

  void _maybeUpdateRoute(LatLng? myPos, LatLng peerPos) async {
    if (myPos == null) return;

    final now = DateTime.now();

    double distanceMoved = 0;

    if (_lastRoutePos != null) {
      distanceMoved = Geolocator.distanceBetween(
        _lastRoutePos!.latitude,
        _lastRoutePos!.longitude,
        myPos.latitude,
        myPos.longitude,
      );
    }

    if (_lastRouteFetch == null ||
        (now.difference(_lastRouteFetch!).inSeconds > 60 &&
            distanceMoved > 200)) {
      _lastRouteFetch = now;
      _lastRoutePos = myPos;

      try {
        final points = await _routingService.getWaterfallRoute(myPos, peerPos);

        state = AsyncData(state.value!.copyWith(routePoints: points));
      } catch (e) {
        debugPrint('[Routing] Error: $e');
      }
    }
  }

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
