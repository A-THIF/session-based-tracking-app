// lib/src/views/auth/route_sign_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RouteSignScreen extends ConsumerWidget {
  const RouteSignScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_searching, size: 80, color: Color(0xFF00E676)),
            const SizedBox(height: 20),
            const Text(
              "TRACE",
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8),
            ),
            const SizedBox(height: 10),
            const Text(
              "Privacy-First Live Tracking",
              style: TextStyle(color: Color(0xFF7A9BC0), fontSize: 14),
            ),
            const SizedBox(height: 60),
            
            // Primary: Anonymous
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/auth/anonymous');
              },
              child: const Text("START ANONYMOUSLY", style: TextStyle(color: Color(0xFF0D1B2A), fontWeight: FontWeight.bold)),
            ),
            
            const SizedBox(height: 20),
            
            // Secondary: Email
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1E3A5F)),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/auth/email');
              },
              child: const Text("SIGN IN WITH EMAIL", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}