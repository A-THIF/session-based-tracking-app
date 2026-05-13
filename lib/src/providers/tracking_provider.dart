import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/ably_service.dart';
import '../services/routing_service.dart';
import 'session_provider.dart';
import '../utils/navigation_utils.dart';
import '../utils/kalman_filter.dart';
import '../utils/route_snapper.dart';

const int _kPacketTimeoutMs = 7000;

// ... inside class TrackingData ...
class TrackingData {
  final LatLng? myPos;
  final LatLng? peerPos;
  // 🟢 ADD THESE TWO FIELDS
  final double myHeading;
  final double peerHeading;
  final double mySpeedKmh; // 🟢 Add this
  final double peerSpeedKmh; // 🟢 Add this
  final bool isSpotlightActive;
  final bool isPeerSpotlighting;

  final List<LatLng> myPath;
  final List<LatLng> peerPath;
  final List<LatLng> routePoints;
  final String distanceLabel;
  final String etaLabel;
  final bool isPeerTimeout;
  final double roadDistance;
  final int roadDuration;
  final double targetBearing;
  final bool isCompassMode;

  const TrackingData({
    this.myPos,
    this.peerPos,
    this.myHeading = 0, // 🟢 Initialize
    this.peerHeading = 0, // 🟢 Initialize
    this.myPath = const [],
    this.peerPath = const [],
    this.routePoints = const [],
    this.distanceLabel = '—',
    this.etaLabel = '—',
    this.isPeerTimeout = false,
    this.roadDistance = 0,
    this.roadDuration = 0,
    this.targetBearing = 0,
    this.isCompassMode = false,
    this.mySpeedKmh = 0,
    this.peerSpeedKmh = 0,
    this.isSpotlightActive = false,
    this.isPeerSpotlighting = false,
  });

  TrackingData copyWith({
    LatLng? myPos,
    LatLng? peerPos,
    double? myHeading, // 🟢 Add to copyWith
    double? peerHeading, // 🟢 Add to copyWith
    List<LatLng>? myPath,
    List<LatLng>? peerPath,
    List<LatLng>? routePoints,
    String? distanceLabel,
    String? etaLabel,
    double? roadDistance,
    int? roadDuration,
    bool? isPeerTimeout,
    double? targetBearing,
    bool? isCompassMode,
    double? mySpeedKmh, // 🟢 Add to copyWith
    double? peerSpeedKmh, // 🟢 Add to copyWith
    bool? isSpotlightActive,
    bool? isPeerSpotlighting,
  }) {
    return TrackingData(
      myPos: myPos ?? this.myPos,
      peerPos: peerPos ?? this.peerPos,
      myHeading: myHeading ?? this.myHeading, // 🟢 Update
      peerHeading: peerHeading ?? this.peerHeading, // 🟢 Update
      myPath: myPath ?? this.myPath,
      peerPath: peerPath ?? this.peerPath,
      routePoints: routePoints ?? this.routePoints,
      distanceLabel: distanceLabel ?? this.distanceLabel,
      etaLabel: etaLabel ?? this.etaLabel,
      isPeerTimeout: isPeerTimeout ?? this.isPeerTimeout,
      roadDistance: roadDistance ?? this.roadDistance,
      roadDuration: roadDuration ?? this.roadDuration,
      targetBearing: targetBearing ?? this.targetBearing,
      isCompassMode: isCompassMode ?? this.isCompassMode,
      mySpeedKmh: mySpeedKmh ?? this.mySpeedKmh, // 🟢 Update
      peerSpeedKmh: peerSpeedKmh ?? this.peerSpeedKmh, // 🟢 Update
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

  // 🟢 FIXED: Class-level Filter Declarations
  final KalmanFilter _myLatFilter = KalmanFilter(q: 0.0001, r: 0.001);
  final KalmanFilter _myLngFilter = KalmanFilter(q: 0.0001, r: 0.001);
  KalmanFilter? _peerLatFilter;
  KalmanFilter? _peerLngFilter;
  bool _filtersInitialized = false;

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

  void toggleSpotlight() {
    final current = state.valueOrNull;
    if (current == null) return;

    final newState = !current.isSpotlightActive;
    state = AsyncData(current.copyWith(isSpotlightActive: newState));

    // Notify peer via Ably
    ref.read(ablyServiceProvider).publishSpotlight(newState);
  }

  void dismissPeerSpotlight() {
    final current = state.valueOrNull;
    if (current == null) return;

    // Tell peer we found them — turns off their pulse too
    ref.read(ablyServiceProvider).publishSpotlight(false);
    state = AsyncData(current.copyWith(isPeerSpotlighting: false));
  }

  void _startGpsPublisher(AblyService ablyService, String myDeviceId) {
    _gpsSub =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.best,
            intervalDuration: const Duration(seconds: 1),
            distanceFilter: 0,
          ),
        ).listen((pos) {
          // 🟢 FIXED: Filter initialization and processing moved INSIDE the listener
          if (!_filtersInitialized) {
            _myLatFilter.reset(pos.latitude);
            _myLngFilter.reset(pos.longitude);
            _filtersInitialized = true;
          }

          final smoothLat = _myLatFilter.filter(pos.latitude);
          final smoothLng = _myLngFilter.filter(pos.longitude);
          final rawMe = LatLng(smoothLat, smoothLng);

          // 🟢 APPLY SNAP-TO-ROAD
          // If we have route points, snap the smoothed GPS to the blue line
          final currentData = state.valueOrNull;
          LatLng me = rawMe;
          if (currentData != null && currentData.routePoints.isNotEmpty) {
            me = RouteSnapper.snapToRoute(rawMe, currentData.routePoints);
          }

          // Publish smoothed location + heading so peer can render our arrow
          ablyService.publishLocation(
            myDeviceId,
            smoothLat,
            smoothLng,
            heading: pos.heading,
            speed: pos.speed, // 🟢 Add speed to publishLocation
          );

          final current = state.valueOrNull ?? const TrackingData();
          final speedKmh = (pos.speed < 0 ? 0.0 : pos.speed) * 3.6;
          state = AsyncData(
            _recalc(
              current.copyWith(
                myPos: me,
                myHeading: pos.heading,
                mySpeedKmh: speedKmh,
              ),
            ),
          );
        });
  }

  void disableCompassMode() {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(isCompassMode: false));
    }
  }

  void _startPeerListener(AblyService ablyService, String myDeviceId) {
    debugPrint('[LiveTracking] Starting peer listener');

    _ablySub = ablyService.getLocationStream().listen(
      (msg) {
        // 🟢 1. Handle spotlight signal FIRST
        if (msg.name == 'spotlight') {
          final raw = Map<String, dynamic>.from(msg.data as Map);
          final isOn = raw['active'] as bool? ?? false;
          final current = state.valueOrNull ?? const TrackingData();
          state = AsyncData(current.copyWith(isPeerSpotlighting: isOn));
          return; // Stop here for spotlight messages
        }
        if (msg.name != 'location_update' || msg.data == null) return;

        final raw = Map<String, dynamic>.from(msg.data as Map);
        final senderId = (raw['deviceId'] ?? '').toString();

        if (senderId == myDeviceId) return;

        final rawLat = (raw['lat'] as num).toDouble();
        final rawLng = (raw['lng'] as num).toDouble();
        final rawHeading = (raw['heading'] as num?)?.toDouble() ?? 0.0;
        final rawSpeed = (raw['speed'] as num?)?.toDouble() ?? 0.0;
        final peerSpeedKmh = (rawSpeed < 0 ? 0.0 : rawSpeed) * 3.6;
        // Peer filter initialization using reset()
        if (_peerLatFilter == null || _peerLngFilter == null) {
          _peerLatFilter = KalmanFilter(q: 0.0001, r: 0.001);
          _peerLngFilter = KalmanFilter(q: 0.0001, r: 0.001);
          _peerLatFilter!.reset(rawLat);
          _peerLngFilter!.reset(rawLng);
        }

        final peer = LatLng(
          _peerLatFilter!.filter(rawLat),
          _peerLngFilter!.filter(rawLng),
        );

        _lastPeerPacket = DateTime.now();
        final current = state.valueOrNull ?? const TrackingData();

        if (_currentSessionCode != null) {
          _maybeUpdateRoute(current.myPos, peer);
        }

        state = AsyncData(
          current.copyWith(
            peerPos: peer,
            peerHeading: rawHeading,
            peerSpeedKmh: peerSpeedKmh,
            isPeerTimeout: false,
          ),
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
        final routeData = await _routingService.getWaterfallRoute(
          myPos,
          peerPos,
        );

        final dist = routeData.distanceMeters;
        final distLabel = dist >= 1000
            ? '${(dist / 1000).toStringAsFixed(2)} km'
            : '${dist.toStringAsFixed(0)} m';

        final etaSec = routeData.durationSeconds;
        final etaLabel = etaSec > 60
            ? '${etaSec ~/ 60}m ${etaSec % 60}s'
            : '${etaSec}s';

        state = AsyncData(
          _recalc(
            state.value!.copyWith(
              routePoints: routeData.points,
              distanceLabel: distLabel,
              etaLabel: etaLabel,
              roadDistance: dist,
              roadDuration: etaSec,
            ),
          ),
        );
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

    // 🟢 Haptic Feedback Trigger for proximity
    if (dist < 5) {
      HapticFeedback.vibrate();
    }

    final etaSec = (dist / 1.4).round();
    final distLabel = dist >= 1000
        ? '${(dist / 1000).toStringAsFixed(2)} km'
        : '${dist.toStringAsFixed(0)} m';

    final etaLabel = etaSec > 60
        ? '${etaSec ~/ 60}m ${etaSec % 60}s'
        : '${etaSec}s';

    double bearing;
    if (data.routePoints.length > 1) {
      final targetIndex = data.routePoints.length > 5 ? 5 : 1;
      bearing = NavigationUtils.calculateBearing(
        data.myPos!,
        data.routePoints[targetIndex],
      );
    } else {
      bearing = NavigationUtils.calculateBearing(data.myPos!, data.peerPos!);
    }

    return data.copyWith(
      distanceLabel: distLabel,
      etaLabel: etaLabel,
      targetBearing: bearing,
      isCompassMode: data.isCompassMode || dist < 25,
    );
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
