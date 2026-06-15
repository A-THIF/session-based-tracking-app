// TODO Implement this library.
class Session {
  final String code;
  final DateTime? expiresAt;

  Session({required this.code, this.expiresAt});

  factory Session.fromJson(Map<String, dynamic> json) {
    // Support both camelCase ('expiresAt' from createSession)
    // and snake_case ('expires_at' from DB row passthrough).
    final rawExpiry = json['expiresAt'] ?? json['expires_at'];
    return Session(
      code: json['code'] ?? '',
      expiresAt: rawExpiry != null
          ? DateTime.tryParse(rawExpiry.toString())
          : null,
    );
  }
}
