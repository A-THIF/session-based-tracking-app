import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/session_model.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class ApiService {
  final String _baseUrl = AppConstants.baseUrl;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
   Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return 'android_${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return 'ios_${iosInfo.identifierForVendor}';
      } else {
        return 'unknown_device';
      }
    } catch (e) {
      print("Error getting device ID: $e");
      return 'error_device';
    }
  }

  Future<Map<String, dynamic>> createSession(int duration) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/session/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'duration': duration}),
    );
    return jsonDecode(response.body);
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
    } else {
      throw Exception(data['error'] ?? 'Join failed');
    }
  }

  Future<Map<String, dynamic>> getSessionDetails(String code) async {
    final response = await http.get(Uri.parse('$_baseUrl/session/$code'));
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getAblyToken(String code) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/auth?sessionCode=$code'),
    );
    return jsonDecode(response.body);
  }
}
