// TODO Implement this library.
class Session {
  final String code;
  final String id;

  Session({required this.code, required this.id});

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(code: json['code'] ?? '', id: json['id'] ?? '');
  }
}
