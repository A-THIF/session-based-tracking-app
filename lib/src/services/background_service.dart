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
      autoStart: false, // Start manually when session begins
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
  final ably = AblyService(); // This is a NEW instance for the background

  service.on('startTracking').listen((event) async {
    final sessionCode = event?['sessionCode'];
    final deviceId = event?['deviceId'];

    if (sessionCode == null || deviceId == null) return;

    // IMPORTANT: You must re-initialize with the session code in the background
    await ably.initAbly(sessionCode, deviceId);

    Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationText: "Trace is sharing your location live",
          notificationTitle: "Running in Background",
          enableWakeLock: true,
        ),
      ),
    ).listen((position) {
      ably.publishLocation(deviceId, position.latitude, position.longitude);
    });
  });
}
