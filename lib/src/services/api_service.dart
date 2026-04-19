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
        // Use manufacturer + model for a readable name like "Xiaomi 23090RA98I"
        return '${androidInfo.manufacturer}_${androidInfo.model}'.replaceAll(
          ' ',
          '_',
        );
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return (iosInfo.name ?? 'iPhone').replaceAll(' ', '_');
      }
      return 'unknown_device';
    } catch (e) {
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

  Future<String> getDeviceName() async {
    return await getDeviceId();
  }

  Future<Map<String, dynamic>> getAblyToken(String code) async {
    final String deviceId = await getDeviceId(); // Get the ID first
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/auth?sessionCode=$code&clientId=$deviceId',
      ), // Send it
    );
    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      return data;
    } else {
      print("Backend Auth Error: ${data['message']}");
      throw Exception("Ably Token generation failed");
    }
  }
}
