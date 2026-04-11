import 'package:flutter/material.dart';

import 'src/constants/app_colors.dart';
import 'src/constants/retro_theme.dart';
import 'src/views/home_screen.dart';

void main() {
  runApp(const SessionTrackingApp());
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
