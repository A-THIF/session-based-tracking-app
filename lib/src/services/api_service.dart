import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/session_model.dart';
import '../config/constants.dart';
import 'user_service.dart';

class ApiService {
  final String _baseUrl = AppConfig.baseUrl;
  final UserService _userService = UserService();

  // ─── Identity Helpers ──────────────────────────────────────────

  Future<String> getDeviceId() async {
    // Returns the persistent UUID from storage
    final profile = await _userService.getUserProfile();
    return profile?.uuid ?? 'unknown_device';
  }

  Future<String> getDisplayName() async {
    final profile = await _userService.getUserProfile();
    return profile?.username ?? 'Guest';
  }

  // ─── Session Management ────────────────────────────────────────

  Future<Map<String, dynamic>> createSession(int duration) async {
    try {
      final deviceId = await getDeviceId();
      final response = await http.post(
        Uri.parse('$_baseUrl/session/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'duration': duration, 'deviceId': deviceId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Create Session Error: $e');
      return {'success': false, 'error': 'Connection failed'};
    }
  }

  Future<Session> joinSession(String code, String deviceId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/session/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'deviceId': deviceId}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Session.fromJson(data['session']);
    }

    throw Exception(data['error'] ?? 'Join failed');
  }

  Future<bool> endSession(String code) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/session/end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('End session failed: $e');
      return false;
    }
  }

  // ─── Tracking & Real-time ──────────────────────────────────────

  Future<Map<String, dynamic>> getAblyToken(String code) async {
    final deviceId = await getDeviceId();

    final response = await http.get(
      Uri.parse('$_baseUrl/auth?sessionCode=$code&clientId=$deviceId'),
    );

    final data = jsonDecode(response.body);

    if (data['success'] == true || data['token'] != null) {
      return data;
    }

    throw Exception("Ably Token generation failed");
  }

  // ─── Session Details ───────────────────────────────────────────
  Future<Map<String, dynamic>> getSessionDetails(String code) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/session/$code'));
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Get session details failed: $e');
      return {'success': false, 'error': 'Could not fetch session info'};
    }
  }         

  // ─── Utility & Logging ─────────────────────────────────────────

  Future<void> sendRemoteLog(
    String event,
    String sessionId,
    String message,
  ) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/session/audit/log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'event': event,
          'session': sessionId,
          'message': message,
          'device': await getDeviceId(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Remote log failed: $e');
    }
  }
}