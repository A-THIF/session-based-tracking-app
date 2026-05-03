// lib/src/config/constants.dart
import 'env.dart';

class AppConfig {
  // Pulls from the obfuscated Envied class
  static final String baseUrl = Env.backendUrl;

  // These are now handled in the BACKEND, so we can remove the keys from here
  // Keeping the logic constants
  static const int routeUpdateIntervalSeconds = 60;
  static const int routeUpdateDistanceMeters = 200;
}
