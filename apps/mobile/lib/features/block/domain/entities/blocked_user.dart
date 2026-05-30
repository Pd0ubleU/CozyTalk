class BlockedUser {
  final String uid;
  final String? displayName;
  final DateTime blockedAt;

  const BlockedUser({
    required this.uid,
    this.displayName,
    required this.blockedAt,
  });
}
