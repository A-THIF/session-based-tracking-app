import 'dart:async'; // ✅ REQUIRED
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'ably_service.dart';

/// 🔥 STEP 1: Initialize service (CALL FROM MAIN)
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'trace_foreground',
      initialNotificationTitle: 'Trace Active',
      initialNotificationContent: 'Initializing...',
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
  );
}

/// 🔥 STEP 2: Background entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final ably = AblyService();

  StreamSubscription<Position>? positionSub;
  bool isInitialized = false;

  /// ▶️ START TRACKING
  service.on('startTracking').listen((event) async {
    final sessionCode = event?['sessionCode'];
    final deviceId = event?['deviceId'];

    if (sessionCode == null || deviceId == null) return;

    // 🧹 Prevent duplicate listeners
    await positionSub?.cancel();

    // 🔌 Initialize Ably only once
    if (!isInitialized) {
      await ably.initAbly(sessionCode, deviceId);
      isInitialized = true;
    }

    // 🔐 Ensure permissions
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      service.stopSelf(); // ❗ stop useless service
      return;
    }

    // 📍 Start location stream
    positionSub =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationText: "Trace is sharing your location live",
              notificationTitle: "Background Tracking Active",
              enableWakeLock: true,
            ),
          ),
        ).listen(
          (position) {
            ably.publishLocation(
              deviceId,
              position.latitude,
              position.longitude,
            );
          },
          onError: (error) {
            // ⚠️ Optional: log / retry logic
            // print("Location stream error: $error");
          },
        );
  });

  /// 🛑 STOP TRACKING
  service.on('stopTracking').listen((event) async {
    await positionSub?.cancel();
    positionSub = null;
  });

  /// 💀 FULL SERVICE STOP (app kill / manual stop)
  service.on('stopService').listen((event) async {
    await positionSub?.cancel();
    positionSub = null;
    service.stopSelf();
  });
}
