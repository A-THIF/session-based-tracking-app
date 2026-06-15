import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:ably_flutter/ably_flutter.dart' as ably;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'trace_foreground',
    'Trace Live Tracking',
    description: 'Foreground service for live location tracking',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'trace_foreground',
      initialNotificationTitle: 'Trace Active',
      initialNotificationContent: 'Initializing...',
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  ably.Realtime? realtime;
  ably.RealtimeChannel? channel;
  StreamSubscription<Position>? positionSub;

  service.on('stopService').listen((event) async {
    await positionSub?.cancel();
    realtime?.close();
    service.stopSelf();
  });

  service.on('startTracking').listen((event) async {
    final String? sessionCode = event?['sessionCode'];
    final String? deviceId = event?['deviceId'];
    final String? backendUrl = event?['backendUrl'];

    if (sessionCode == null || deviceId == null || backendUrl == null) return;

    await positionSub?.cancel();

    try {
      // Get Ably token directly in the background isolate
      final tokenResponse = await http.get(
        Uri.parse(
          '$backendUrl/auth?sessionCode=$sessionCode&clientId=$deviceId',
        ),
      );
      final tokenData = jsonDecode(tokenResponse.body);
      final String? tokenString = tokenData['token'] as String?;

      if (tokenString == null) return;

      final opts = ably.ClientOptions();
      opts.tokenDetails = ably.TokenDetails(tokenString);
      opts.clientId = deviceId;

      realtime = ably.Realtime(options: opts);
      channel = realtime!.channels.get('session_$sessionCode');
      await realtime!.connect();
    } catch (e) {
      return;
    }

    // Start GPS stream
    positionSub =
        Geolocator.getPositionStream(
          // ... inside positionSub = Geolocator.getPositionStream ...
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0, // 🟢 Set to 0 so we get every single movement
            intervalDuration: const Duration(
              milliseconds: 1000,
            ), // 🟢 1s base interval
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationText: "Trace is sharing your location",
              notificationTitle: "Live Tracking Active",
              enableWakeLock: true,
            ),
          ),
        ).listen((position) {
          // 🟢 LOGIC: Google-style adaptive polling
          // If we are moving fast (> 4m/s or ~15km/h), we ensure Ably fires immediately.
          // The distanceFilter is 0, so we just publish every valid tick.

          channel?.publish(
            name: 'location_update',
            data: {
              'lat': position.latitude,
              'lng': position.longitude,
              'deviceId': deviceId,
              'heading': position.heading, // 🟢 Added heading
              'speed': position.speed, // 🟢 Added raw speed (m/s)
            },
          );
        });
  });
}
