import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
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

  final ably = AblyService();

  /// Android-specific controls
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  /// Stop service
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  /// 🔥 START TRACKING EVENT
  service.on('startTracking').listen((event) async {
    final sessionCode = event?['sessionCode'];
    final deviceId = event?['deviceId'];

    if (sessionCode == null || deviceId == null) return;

    /// ✅ Initialize Ably
    await ably.initAbly(sessionCode);

    /// ✅ Start location stream
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    ).listen((position) {
      /// ✅ Publish to Ably
      ably.publishLocation(deviceId, position.latitude, position.longitude);

      /// ✅ Update notification (Android)
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Trace: Active Session",
          content: "Sharing location in $sessionCode",
        );
      }
    });
  });
}
