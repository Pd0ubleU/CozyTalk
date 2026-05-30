class AdminBlockedEntry {
  final String uid;
  final String? displayName;
  final DateTime? blockedAt;

  const AdminBlockedEntry({
    required this.uid,
    this.displayName,
    this.blockedAt,
  });
}
