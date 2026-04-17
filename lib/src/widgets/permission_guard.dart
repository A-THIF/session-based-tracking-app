import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class PermissionGuard {
  static Future<bool> checkSettings(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if GPS is actually turned on
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showAlert(context, "GPS Disabled", "Please turn on your phone's GPS location.");
      return false;
    }

    // 2. Check Permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showAlert(context, "Permission Denied", "We need location access to track your path.");
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _showAlert(context, "Permissions Blocked", "You have permanently blocked location. Please enable it in Settings.");
      return false;
    }

    return true;
  }

  static void _showAlert(BuildContext context, String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Color(0xFF00D1B2))),
          ),
        ],
      ),
    );
  }
}