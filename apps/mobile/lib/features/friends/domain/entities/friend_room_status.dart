class FriendRoomStatus {
  final String roomId;
  final int memberCount;
  final int maxUsers;
  final bool isLocked;
  final String mode;

  const FriendRoomStatus({
    required this.roomId,
    required this.memberCount,
    required this.maxUsers,
    required this.isLocked,
    required this.mode,
  });
}
