import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/data/datasources/friends_datasource.dart';
import 'package:mobile/features/friends/data/models/app_user_model.dart';
import 'package:mobile/features/friends/data/models/friend_message_model.dart';
import 'package:mobile/features/friends/data/models/friend_model.dart';
import 'package:mobile/features/friends/data/models/friend_request_model.dart';
import 'package:mobile/features/friends/data/repositories/friends_repository_impl.dart';
import 'package:mobile/features/friends/domain/entities/friend_room_status.dart';

class _FakeFriendsDatasource implements FriendsDatasource {
  final List<AppUserModel> users;
  final List<FriendModel> friends;
  final List<FriendRequestModel> requests;
  final List<FriendMessageModel> messages;
  final String mockCurrentUid;
  Exception? error;

  int sendFriendRequestCount = 0;
  String? lastToUid;
  String? lastFromDisplayName;

  int acceptFriendRequestCount = 0;
  String? lastAcceptedRequestId;

  int declineFriendRequestCount = 0;
  String? lastDeclinedRequestId;

  int removeFriendCount = 0;
  String? lastRemovedFriendshipId;

  int sendMessageCount = 0;
  String? lastChatRoomId;
  String? lastText;
  String? lastSenderDisplayName;

  _FakeFriendsDatasource({
    this.users = const [],
    this.friends = const [],
    this.requests = const [],
    this.messages = const [],
    this.mockCurrentUid = 'current-uid',
  });

  @override
  String get currentUid => mockCurrentUid;

  @override
  Stream<List<AppUserModel>> watchAllUsers() => Stream.value(users);

  @override
  Stream<List<FriendModel>> watchFriends() => Stream.value(friends);

  @override
  Stream<List<FriendRequestModel>> watchIncomingRequests() =>
      Stream.value(requests);

  @override
  Stream<List<FriendMessageModel>> watchMessages(String chatRoomId) {
    lastChatRoomId = chatRoomId;
    return Stream.value(messages);
  }

  @override
  Stream<bool> watchFriendPresence(String friendUid) => Stream.value(false);

  @override
  Stream<String> watchFriendLastMessage(String chatRoomId) => Stream.value('');

  @override
  Stream<FriendRoomStatus?> watchFriendRoom(String friendUid) =>
      Stream.value(null);

  @override
  Future<void> sendFriendRequest({
    required String toUid,
    required String toDisplayName,
    required String fromDisplayName,
  }) async {
    if (error != null) throw error!;
    sendFriendRequestCount++;
    lastToUid = toUid;
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

void main() {
  group('FriendsRepositoryImpl', () {
    group('watchAllUsers', () {
      test('maps AppUserModel list to AppUser list', () async {
        final datasource = _FakeFriendsDatasource(
          users: const [AppUserModel(uid: 'u1', displayName: 'Alice')],
        );
        final repo = FriendsRepositoryImpl(datasource);
        final result = await repo.watchAllUsers().first;
        expect(result, hasLength(1));
        expect(result[0].uid, 'u1');
        expect(result[0].displayName, 'Alice');
      });

      test('returns empty list when datasource has no users', () async {
        final repo = FriendsRepositoryImpl(_FakeFriendsDatasource());
        final result = await repo.watchAllUsers().first;
        expect(result, isEmpty);
      });
    });

    group('watchFriends', () {
      test('maps FriendModel list to Friend list using currentUid', () async {
        final datasource = _FakeFriendsDatasource(
          friends: const [
            FriendModel(
              id: 'current-uid_uid-2',
              users: ['current-uid', 'uid-2'],
              displayNames: {'current-uid': 'Me', 'uid-2': 'Bob'},
              chatRoomId: 'current-uid_uid-2',
              createdAt: 0,
            ),
          ],
          mockCurrentUid: 'current-uid',
        );
        final repo = FriendsRepositoryImpl(datasource);
        final result = await repo.watchFriends().first;
        expect(result, hasLength(1));
        expect(result[0].friendUid, 'uid-2');
        expect(result[0].friendDisplayName, 'Bob');
      });

      test('returns empty list when no friendships', () async {
        final repo = FriendsRepositoryImpl(_FakeFriendsDatasource());
        expect(await repo.watchFriends().first, isEmpty);
      });
    });

    group('watchIncomingRequests', () {
      test('maps FriendRequestModel list to FriendRequest list', () async {
        final datasource = _FakeFriendsDatasource(
          requests: const [
            FriendRequestModel(
              id: 'req-1',
              fromUid: 'u1',
              fromDisplayName: 'Alice',
              toUid: 'current-uid',
              toDisplayName: 'Me',
              status: 'pending',
              createdAt: 0,
            ),
          ],
        );
        final repo = FriendsRepositoryImpl(datasource);
        final result = await repo.watchIncomingRequests().first;
        expect(result, hasLength(1));
        expect(result[0].id, 'req-1');
        expect(result[0].fromDisplayName, 'Alice');
      });
    });

    group('watchMessages', () {
      test('passes chatRoomId to datasource', () async {
        final datasource = _FakeFriendsDatasource(
          messages: const [
            FriendMessageModel(
              id: 'msg-1',
              senderId: 'u1',
              senderDisplayName: 'Alice',
              text: 'hi',
              timestamp: 1000,
            ),
          ],
        );
        final repo = FriendsRepositoryImpl(datasource);
        await repo.watchMessages('room-xyz').first;
        expect(datasource.lastChatRoomId, 'room-xyz');
      });

      test('maps FriendMessageModel list to FriendMessage list', () async {
        final datasource = _FakeFriendsDatasource(
          messages: const [
            FriendMessageModel(
              id: 'msg-2',
              senderId: 'u2',
              senderDisplayName: 'Bob',
              text: 'hello',
              timestamp: 5000,
            ),
          ],
        );
        final repo = FriendsRepositoryImpl(datasource);
        final result = await repo.watchMessages('room-1').first;
        expect(result, hasLength(1));
        expect(result[0].text, 'hello');
        expect(result[0].timestamp, DateTime.fromMillisecondsSinceEpoch(5000));
      });
    });

    group('sendFriendRequest', () {
      test('delegates to datasource with correct parameters', () async {
        final datasource = _FakeFriendsDatasource();
        final repo = FriendsRepositoryImpl(datasource);
        await repo.sendFriendRequest(
          toUid: 'uid-2',
          toDisplayName: 'Bob',
          fromDisplayName: 'Alice',
        );
        expect(datasource.sendFriendRequestCount, 1);
        expect(datasource.lastToUid, 'uid-2');
        expect(datasource.lastFromDisplayName, 'Alice');
      });

      test('propagates datasource exception', () {
        final datasource = _FakeFriendsDatasource()
          ..error = Exception('send failed');
        final repo = FriendsRepositoryImpl(datasource);
        expect(
          () => repo.sendFriendRequest(
            toUid: 'uid-2',
            toDisplayName: 'Bob',
            fromDisplayName: 'Alice',
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('acceptFriendRequest', () {
      test('delegates to datasource', () async {
        final datasource = _FakeFriendsDatasource();
        final repo = FriendsRepositoryImpl(datasource);
        await repo.acceptFriendRequest(
          requestId: 'req-1',
          fromUid: 'u1',
          fromDisplayName: 'Alice',
          myDisplayName: 'Bob',
        );
        expect(datasource.acceptFriendRequestCount, 1);
        expect(datasource.lastAcceptedRequestId, 'req-1');
      });
    });

    group('declineFriendRequest', () {
      test('delegates requestId to datasource', () async {
        final datasource = _FakeFriendsDatasource();
        final repo = FriendsRepositoryImpl(datasource);
        await repo.declineFriendRequest(requestId: 'req-2');
        expect(datasource.declineFriendRequestCount, 1);
        expect(datasource.lastDeclinedRequestId, 'req-2');
      });
    });

    group('removeFriend', () {
      test('delegates friendshipId to datasource', () async {
        final datasource = _FakeFriendsDatasource();
        final repo = FriendsRepositoryImpl(datasource);
        await repo.removeFriend(friendshipId: 'uid-1_uid-2');
        expect(datasource.removeFriendCount, 1);
        expect(datasource.lastRemovedFriendshipId, 'uid-1_uid-2');
      });
    });

    group('sendMessage', () {
      test('delegates all parameters to datasource', () async {
        final datasource = _FakeFriendsDatasource();
        final repo = FriendsRepositoryImpl(datasource);
        await repo.sendMessage(
          chatRoomId: 'room-1',
          text: 'Hi there',
          senderDisplayName: 'Alice',
        );
        expect(datasource.sendMessageCount, 1);
        expect(datasource.lastChatRoomId, 'room-1');
        expect(datasource.lastText, 'Hi there');
        expect(datasource.lastSenderDisplayName, 'Alice');
      });

      test('propagates datasource exception', () {
        final datasource = _FakeFriendsDatasource()
          ..error = Exception('network error');
        final repo = FriendsRepositoryImpl(datasource);
        expect(
          () => repo.sendMessage(
            chatRoomId: 'room-1',
            text: 'Hi',
            senderDisplayName: 'Alice',
          ),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
