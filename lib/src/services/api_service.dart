import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/session_model.dart';

class ApiService {
  final String _baseUrl = AppConstants.baseUrl;

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
    return Session.fromJson(data['session']);
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
