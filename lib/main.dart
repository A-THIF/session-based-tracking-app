import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/constants/retro_theme.dart';
import 'src/views/home_screen.dart';
import 'src/services/background_service.dart'; // ✅ ADD THIS

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 🔥 IMPORTANT: Initialize background service
  await initializeService();

  runApp(const ProviderScope(child: SessionTrackingApp()));
}

class SessionTrackingApp extends StatelessWidget {
  const SessionTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Session Tracking App',
      debugShowCheckedModeBanner: false,
      theme: buildRetroTheme(),
      home: const HomeScreen(),
    );
  }
}
