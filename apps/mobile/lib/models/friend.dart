class RoomInfo {
  final String name;
  final String thumbnail;
  final int current;
  final int max;
  final bool isLocked;

  const RoomInfo({
    required this.name,
    required this.thumbnail,
    required this.current,
    required this.max,
    this.isLocked = false,
  });

  bool get isFull => current >= max;
  bool get isOneOnOne => max == 2;
  bool get canJoin => !isFull && !isLocked && !isOneOnOne;
}

class Friend {
  final String friendshipId;
  final String chatRoomId;
  final String name;
  final String username;
  String? note;
  final String lastMessage;
  final bool isOnline;
  int unreadCount;
  final RoomInfo? room;
  final String avatar;
  final String interest;
  bool isBlocked;

  Friend({
    this.friendshipId = '',
    this.chatRoomId = '',
    required this.name,
    required this.username,
    this.note,
    required this.lastMessage,
    required this.isOnline,
    this.unreadCount = 0,
    this.room,
    this.avatar = '',
    this.interest = '',
    this.isBlocked = false,
  });

  Friend copyWith({
    String? friendshipId,
    String? chatRoomId,
    String? name,
    String? username,
    Object? note = _sentinel,
    String? lastMessage,
    bool? isOnline,
    int? unreadCount,
    Object? room = _sentinel,
    String? avatar,
    String? interest,
    bool? isBlocked,
  }) => Friend(
    friendshipId: friendshipId ?? this.friendshipId,
    chatRoomId: chatRoomId ?? this.chatRoomId,
    name: name ?? this.name,
    username: username ?? this.username,
    note: note == _sentinel ? this.note : note as String?,
    lastMessage: lastMessage ?? this.lastMessage,
    isOnline: isOnline ?? this.isOnline,
    unreadCount: unreadCount ?? this.unreadCount,
    room: room == _sentinel ? this.room : room as RoomInfo?,
    avatar: avatar ?? this.avatar,
    interest: interest ?? this.interest,
    isBlocked: isBlocked ?? this.isBlocked,
  );

  bool get isInRoom => room != null;

  // Display name: use note if set, otherwise fall back to username
  String get displayName =>
      (note != null && note!.isNotEmpty) ? note! : username;
}

const _sentinel = Object();

class ChatMessage {
  final String text;
  final bool isMe;
  final String time;
  final bool isGif;

  const ChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
    this.isGif = false,
  });
}
