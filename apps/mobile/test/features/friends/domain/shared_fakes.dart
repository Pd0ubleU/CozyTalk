import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/entities/friend.dart';
import 'package:mobile/features/friends/domain/entities/friend_message.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/domain/entities/friend_room_status.dart';
import 'package:mobile/features/friends/domain/repositories/friends_repository.dart';

class FakeFriendsRepository implements FriendsRepository {
  List<AppUser> allUsers = [];
  List<Friend> friends = [];
  List<FriendRequest> requests = [];
  List<FriendMessage> messages = [];
  Exception? error;

  int sendFriendRequestCount = 0;
  String? lastToUid;
  String? lastToDisplayName;
  String? lastFromDisplayName;

  int acceptFriendRequestCount = 0;
  String? lastAcceptedRequestId;
  String? lastAcceptedFromUid;
  String? lastAcceptedFromDisplayName;
  String? lastAcceptedMyDisplayName;

  int declineFriendRequestCount = 0;
  String? lastDeclinedRequestId;

  int removeFriendCount = 0;
  String? lastRemovedFriendshipId;

  int sendMessageCount = 0;
  String? lastChatRoomId;
  String? lastText;
  String? lastSenderDisplayName;

  bool presenceResult = false;
  String? lastWatchPresenceFriendUid;

  String lastMessageResult = '';
  String? lastWatchLastMessageChatRoomId;

  FriendRoomStatus? roomResult;
  String? lastWatchRoomFriendUid;

  @override
  Stream<List<AppUser>> watchAllUsers() =>
      error != null ? Stream.error(error!) : Stream.value(allUsers);

  @override
  Stream<List<Friend>> watchFriends() =>
      error != null ? Stream.error(error!) : Stream.value(friends);

  @override
  Stream<List<FriendRequest>> watchIncomingRequests() =>
      error != null ? Stream.error(error!) : Stream.value(requests);

  @override
  Stream<List<FriendMessage>> watchMessages(String chatRoomId) {
    lastChatRoomId = chatRoomId;
    return error != null ? Stream.error(error!) : Stream.value(messages);
  }

  @override
  Stream<bool> watchFriendPresence(String friendUid) {
    lastWatchPresenceFriendUid = friendUid;
    return error != null ? Stream.error(error!) : Stream.value(presenceResult);
  }

  @override
  Stream<String> watchFriendLastMessage(String chatRoomId) {
    lastWatchLastMessageChatRoomId = chatRoomId;
    return error != null
        ? Stream.error(error!)
        : Stream.value(lastMessageResult);
  }

  @override
  Stream<FriendRoomStatus?> watchFriendRoom(String friendUid) {
    lastWatchRoomFriendUid = friendUid;
    return error != null ? Stream.error(error!) : Stream.value(roomResult);
  }

  @override
  Future<void> sendFriendRequest({
    required String toUid,
    required String toDisplayName,
    required String fromDisplayName,
  }) async {
    if (error != null) throw error!;
    sendFriendRequestCount++;
    lastToUid = toUid;
    lastToDisplayName = toDisplayName;
    lastFromDisplayName = fromDisplayName;
  }

  @override
  Future<void> acceptFriendRequest({
    required String requestId,
    required String fromUid,
    required String fromDisplayName,
    required String myDisplayName,
  }) async {
    if (error != null) throw error!;
    acceptFriendRequestCount++;
    lastAcceptedRequestId = requestId;
    lastAcceptedFromUid = fromUid;
    lastAcceptedFromDisplayName = fromDisplayName;
    lastAcceptedMyDisplayName = myDisplayName;
  }

  @override
  Future<void> declineFriendRequest({required String requestId}) async {
    if (error != null) throw error!;
    declineFriendRequestCount++;
    lastDeclinedRequestId = requestId;
  }

  @override
  Future<void> removeFriend({required String friendshipId}) async {
    if (error != null) throw error!;
    removeFriendCount++;
    lastRemovedFriendshipId = friendshipId;
  }

  @override
  Future<void> sendMessage({
    required String chatRoomId,
    required String text,
    required String senderDisplayName,
  }) async {
    if (error != null) throw error!;
    sendMessageCount++;
    lastChatRoomId = chatRoomId;
    lastText = text;
    lastSenderDisplayName = senderDisplayName;
  }
}
