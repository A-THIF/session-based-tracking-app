import 'env.dart';

class AppConfig {
  // 🟢 FIXED: Use the obfuscated Env variable, don't hardcode!
  static final String baseUrl = Env.backendUrl;

  static const int routeUpdateIntervalSeconds = 60;
  static const int routeUpdateDistanceMeters = 200;
}