import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

// Battery level below which GPS polling is throttled (0–100).
const int _kLowBatteryThreshold = 15;

class TrackingData {
  final LatLng? myPos;
  final LatLng? peerPos;
  final double myHeading;
  final double peerHeading;
  final double mySpeedKmh;
  final double peerSpeedKmh;
  final bool isSpotlightActive;
  final bool isPeerSpotlighting;
  final bool isGpsLost;         // Task 12: GPS signal lost
  final bool showBatteryWarning; // Task 13: one-shot low-battery snackbar flag

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
    this.myHeading = 0,
    this.peerHeading = 0,
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
    this.isGpsLost = false,
    this.showBatteryWarning = false,
  });

  TrackingData copyWith({
    LatLng? myPos,
    LatLng? peerPos,
    double? myHeading,
    double? peerHeading,
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
    double? mySpeedKmh,
    double? peerSpeedKmh,
    bool? isSpotlightActive,
    bool? isPeerSpotlighting,
    bool? isGpsLost,
    bool? showBatteryWarning,
  }) {
    return TrackingData(
      myPos: myPos ?? this.myPos,
      peerPos: peerPos ?? this.peerPos,
      myHeading: myHeading ?? this.myHeading,
      peerHeading: peerHeading ?? this.peerHeading,
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
      mySpeedKmh: mySpeedKmh ?? this.mySpeedKmh,
      peerSpeedKmh: peerSpeedKmh ?? this.peerSpeedKmh,
      isSpotlightActive: isSpotlightActive ?? this.isSpotlightActive,
      isPeerSpotlighting: isPeerSpotlighting ?? this.isPeerSpotlighting,
      isGpsLost: isGpsLost ?? this.isGpsLost,
      showBatteryWarning: showBatteryWarning ?? this.showBatteryWarning,
    );
  }
}

class LiveTrackingNotifier extends AsyncNotifier<TrackingData> {
  StreamSubscription<Position>? _gpsSub;
  StreamSubscription? _ablySub;
  Timer? _watchdog;
  Timer? _batteryTimer;
  bool _started = false;
  bool _isBatteryLow = false;
  bool _batteryWarningShown = false;
  bool _gpsRetryPending = false; // Fix 2.2: prevents stacked retry timers

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
    _startBatteryMonitor(ablyService, myDeviceId);

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

  /// Called by the UI after showing the low-battery snackbar to reset the flag.
  void clearBatteryWarning() {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(showBatteryWarning: false));
    }
  }

  // ── Task 12 & 13: GPS publisher with error handling + battery throttle ───

  void _startGpsPublisher(AblyService ablyService, String myDeviceId) {
    _gpsSub?.cancel();

    final interval = _isBatteryLow
        ? const Duration(seconds: 5)   // Task 13: throttled
        : const Duration(seconds: 1);  // normal 1Hz

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.best,
        intervalDuration: interval,
        distanceFilter: 0,
      ),
    ).listen(
      (pos) {
        // Recover from GPS loss if it was previously flagged
        final current = state.valueOrNull ?? const TrackingData();
        final wasLost = current.isGpsLost;

        if (!_filtersInitialized) {
          _myLatFilter.reset(pos.latitude);
          _myLngFilter.reset(pos.longitude);
          _filtersInitialized = true;
        }

        final smoothLat = _myLatFilter.filter(pos.latitude);
        final smoothLng = _myLngFilter.filter(pos.longitude);
        final rawMe = LatLng(smoothLat, smoothLng);

        LatLng me = rawMe;
        if (current.routePoints.isNotEmpty) {
          me = RouteSnapper.snapToRoute(rawMe, current.routePoints);
        }

        ablyService.publishLocation(
          myDeviceId,
          smoothLat,
          smoothLng,
          heading: pos.heading,
          speed: pos.speed,
        );

        final speedKmh = (pos.speed < 0 ? 0.0 : pos.speed) * 3.6;
        state = AsyncData(
          _recalc(
            current.copyWith(
              myPos: me,
              myHeading: pos.heading,
              mySpeedKmh: speedKmh,
              // Clear GPS lost flag now that we have a fix
              isGpsLost: wasLost ? false : current.isGpsLost,
            ),
          ),
        );
      },
      // Fix 2.2: GPS stream error — flag loss and schedule auto-recovery.
      // The stream closes on error so we must restart it explicitly.
      onError: (Object err) {
        debugPrint('[GPS] Stream error: $err');
        final isGpsError = err is LocationServiceDisabledException ||
            err is PermissionDeniedException;
        if (isGpsError) {
          final current = state.valueOrNull;
          if (current != null && !current.isGpsLost) {
            state = AsyncData(current.copyWith(isGpsLost: true));
          }
          // Retry in 10s — once only; if the stream still fails the next
          // onError will schedule another retry, preventing stacking.
          if (!_gpsRetryPending) {
            _gpsRetryPending = true;
            Future.delayed(const Duration(seconds: 10), () {
              _gpsRetryPending = false;
              if (_started) {
                debugPrint('[GPS] Retrying stream after error...');
                _startGpsPublisher(ablyService, myDeviceId);
              }
            });
          }
        }
      },
    );
  }

  // ── Task 13: Battery monitor — polls every 60s, restarts GPS on change ───

  void _startBatteryMonitor(AblyService ablyService, String myDeviceId) {
    _batteryTimer?.cancel();
    _batteryTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        final int level = await _getBatteryLevel();
        final nowLow = level <= _kLowBatteryThreshold;

        if (nowLow != _isBatteryLow) {
          _isBatteryLow = nowLow;
          // Restart GPS stream with the new interval
          _startGpsPublisher(ablyService, myDeviceId);

          if (nowLow && !_batteryWarningShown) {
            _batteryWarningShown = true;
            // Signal the UI to show the snackbar once via state flag
            final current = state.valueOrNull;
            if (current != null) {
              state = AsyncData(current.copyWith(showBatteryWarning: true));
            }
          }
        }
      } catch (_) {
        // Battery check is best-effort; don't crash tracking
      }
    });
  }

  /// Reads battery level (0–100) via the platform channel that ships with
  /// Flutter's services binding. Returns 100 if unavailable so we default
  /// to normal polling — no extra package needed.
  ///
  /// Swap in `battery_plus` by replacing this method body with:
  ///   `return (await Battery().batteryLevel);`
  Future<int> _getBatteryLevel() async {
    try {
      final int level = await const MethodChannel('flutter/battery')
          .invokeMethod<int>('getBatteryLevel') ?? 100;
      return level;
    } catch (_) {
      return 100;
    }
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
    _batteryTimer?.cancel();
    // Detach channel subscriptions so a notifier rebuild doesn't create
    // a second listener on the same channel (Fix 2.1).
    try {
      ref.read(ablyServiceProvider).disposeStreams();
    } catch (_) {
      // provider may already be disposed
    }
    _gpsRetryPending = false;
    _started = false;
  }
}

final liveTrackingProvider =
    AsyncNotifierProvider<LiveTrackingNotifier, TrackingData>(
      LiveTrackingNotifier.new,
    );
