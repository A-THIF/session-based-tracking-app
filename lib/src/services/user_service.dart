import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../config/constants.dart'; // Make sure this matches your config path
import 'package:flutter/foundation.dart'; // 🟢 This defines debugPrint

class UserService {
  // Use your backend URL from AppConfig
  final String _baseUrl = AppConfig.baseUrl;

  Future<UserProfile?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('user_profile');
    if (stored == null) return null;
    return UserProfile.fromJson(jsonDecode(stored));
  }

  Future<List<String>> fetchUsernameSuggestions() async {
  try {
    // 🟢 CHANGED: Removed /username/ from the path to match your backend routes
    final response = await http.get(
      Uri.parse('$_baseUrl/user/suggestions'), 
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['suggestions']);
    }
    return [];
  } catch (e) {
    debugPrint("Shuffle error: $e");
    return [];
  }
}

  // lib/src/services/user_service.dart

Future<UserProfile> claimIdentity(String username) async {
  final prefs = await SharedPreferences.getInstance();
  
  // 1. Get or Create UUID
  String? uuid = prefs.getString('user_uuid');
  if (uuid == null) {
    uuid = const Uuid().v4();
    await prefs.setString('user_uuid', uuid);
  }

  // 2. Make the request
  final response = await http.post(
    Uri.parse('$_baseUrl/user/identity'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'uuid': uuid, 'username': username}),
  );

  final data = jsonDecode(response.body);

  // 3. Check for Success
  if (response.statusCode == 200 && data['success'] == true) {
    final userMap = data['user'];
    
    // 🟢 CRITICAL CHANGE HERE: 
    // Your log says the backend returns 'id'. We must map it to 'uuid'.
    final profile = UserProfile(
      uuid: userMap['id'],         // Log shows: id: 'f817ec31...'
      username: userMap['username'],
      traceId: userMap['trace_id'],
    );

    // 4. Save and return
    await prefs.setString('user_profile', jsonEncode(profile.toJson()));
    return profile;
  } else {
    // This helps debug exactly what went wrong if it fails again
    debugPrint("Backend Error: ${response.body}");
    throw Exception('CLAIM_FAILED');
  }
}

  Future<void> sendPulse() async {
    final prefs = await SharedPreferences.getInstance();
    final uuid = prefs.getString('user_uuid');
    if (uuid == null) return;

    await http.post(
      Uri.parse('$_baseUrl/user/pulse'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uuid': uuid}),
    );
  }
}
