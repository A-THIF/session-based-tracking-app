class Session {
  const Session({
    required this.id,
    required this.name,
    required this.startedAt,
    this.isActive = true,
  });

  final String id;
  final String name;
  final DateTime startedAt;
  final bool isActive;
}
