// TODO Implement this library.
class Session {
  final String code;
  final DateTime? expiresAt;

  Session({required this.code, this.expiresAt});

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      code: json['code'] ?? '',
      expiresAt: json['expires_at'] != null 
          ? DateTime.tryParse(json['expires_at'].toString()) 
          : null,
    );
  }
}
