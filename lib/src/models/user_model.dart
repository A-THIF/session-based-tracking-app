class UserProfile {
  final String uuid;
  final String username;
  final String traceId;

  const UserProfile({
    required this.uuid,
    required this.username,
    required this.traceId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uuid: json['uuid'] as String,
      username: json['username'] as String,
      traceId: json['trace_id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'username': username,
    'trace_id': traceId,
  };
}
