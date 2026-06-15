import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_compass/flutter_compass.dart';

// ── Camera mode ───────────────────────────────────────────────────────────────

enum CameraMode {
  /// Both users visible — crosshair icon, camera fits both markers.
  overview,

  /// Locked to self — compass icon, heading-up rotation active.
  guided,
}

// ── State ─────────────────────────────────────────────────────────────────────

class MapNavigationState {
  final double rotation;
  final double tilt;
  final double zoom;
  final bool isHeadingUp;
  final CameraMode cameraMode;

  MapNavigationState({
    this.rotation = 0.0,
    this.tilt = 0.0,
    this.zoom = 17.0,
    this.isHeadingUp = false,
    this.cameraMode = CameraMode.overview,
  });

  MapNavigationState copyWith({
    double? rotation,
    double? tilt,
    double? zoom,
    bool? isHeadingUp,
    CameraMode? cameraMode,
  }) {
    return MapNavigationState(
      rotation: rotation ?? this.rotation,
      tilt: tilt ?? this.tilt,
      zoom: zoom ?? this.zoom,
      isHeadingUp: isHeadingUp ?? this.isHeadingUp,
      cameraMode: cameraMode ?? this.cameraMode,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class MapNavigationNotifier extends StateNotifier<MapNavigationState> {
  final Ref ref;
  StreamSubscription? _compassSub;

  MapNavigationNotifier(this.ref) : super(MapNavigationState());

  // Called by TrackingScreen when user drags the map manually.
  void resetToOverview() {
    if (state.cameraMode == CameraMode.overview) return;
    state = state.copyWith(
      cameraMode: CameraMode.overview,
      isHeadingUp: false,
      rotation: 0.0,
      tilt: 0.0,
      zoom: 17.0,
    );
    _stopCompassListener();
  }

  // FAB tap — toggle between overview and guided.
  void toggleCameraMode() {
    if (state.cameraMode == CameraMode.overview) {
      state = state.copyWith(
        cameraMode: CameraMode.guided,
        isHeadingUp: true,
        tilt: 35.0,
        zoom: 18.0,
      );
      _startCompassListener();
    } else {
      resetToOverview();
    }
  }

  // Called by the speed sensor — only activates heading-up in guided mode.
  void updateFromSpeed(double speedKmh) {
    if (state.cameraMode != CameraMode.guided) return;

    if (speedKmh > 10.0 && !state.isHeadingUp) {
      state = state.copyWith(isHeadingUp: true, tilt: 35.0, zoom: 18.0);
      _startCompassListener();
    } else if (speedKmh < 3.0 && state.isHeadingUp) {
      state = state.copyWith(
        isHeadingUp: false,
        tilt: 0.0,
        rotation: 0.0,
        zoom: 17.0,
      );
      _stopCompassListener();
    }
  }

  void _startCompassListener() {
    _compassSub?.cancel();
    _compassSub = FlutterCompass.events!.listen((event) {
      final double? rawHeading = event.heading;
      if (rawHeading == null) return;

      // Shortest-path rotation — map rotates opposite to device heading
      double current = state.rotation;
      double target = -rawHeading;
      double diff = (target - current + 180) % 360 - 180;
      if (diff < -180) diff += 360;

      // Low-pass filter: 15% smoothing
      state = state.copyWith(rotation: current + diff * 0.15);
    });
  }

  void _stopCompassListener() {
    _compassSub?.cancel();
    _compassSub = null;
  }

  @override
  void dispose() {
    _stopCompassListener();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final mapNavigationProvider =
    StateNotifierProvider<MapNavigationNotifier, MapNavigationState>(
      (ref) => MapNavigationNotifier(ref),
    );
