class AppConfig {
  static const String baseUrl = String.fromEnvironment('BACKEND_URL');

  static const String stadiaKey = String.fromEnvironment('STADIA_API_KEY');

  static const String orsKey = String.fromEnvironment('ORS_API_KEY');

  static const int routeUpdateIntervalSeconds = 60;
  static const int routeUpdateDistanceMeters = 200;
}
