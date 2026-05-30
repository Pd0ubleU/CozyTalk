import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/entities/friend.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/domain/entities/friend_room_status.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';

void main() {
  group('FriendsState', () {
    test('initial state has empty collections, no loading, no error', () {
      const state = FriendsState();
      expect(state.allUsers, isEmpty);
      expect(state.friends, isEmpty);
      expect(state.incomingRequests, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith updates isLoading', () {
      const state = FriendsState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
      expect(updated.allUsers, isEmpty);
      expect(updated.error, isNull);
    });

    test('copyWith sets error', () {
      const state = FriendsState();
      final updated = state.copyWith(error: 'request failed');
      expect(updated.error, 'request failed');
      expect(updated.isLoading, isFalse);
    });

    test('copyWith clears error with explicit null (sentinel)', () {
      const state = FriendsState(error: 'old error');
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test(
      'copyWith without error argument preserves existing error (sentinel)',
      () {
        const state = FriendsState(error: 'kept error');
        final copy = state.copyWith(isLoading: true);
        expect(copy.error, 'kept error');
      },
    );

    test('copyWith replaces allUsers list', () {
      const state = FriendsState();
      final updated = state.copyWith(
        allUsers: [const AppUser(uid: 'u1', displayName: 'Alice')],
      );
      expect(updated.allUsers, hasLength(1));
      expect(updated.allUsers[0].uid, 'u1');
    });

    test('copyWith replaces friends list', () {
      const state = FriendsState();
      final friend = Friend(
        friendshipId: 'f1',
        friendUid: 'u2',
        friendDisplayName: 'Bob',
        chatRoomId: 'f1',
        friendedAt: DateTime(2024),
      );
      final updated = state.copyWith(friends: [friend]);
      expect(updated.friends, hasLength(1));
      expect(updated.friends[0].friendUid, 'u2');
    });

    test('copyWith replaces incomingRequests list', () {
      const state = FriendsState();
      final request = FriendRequest(
        id: 'req-1',
        fromUid: 'u1',
        fromDisplayName: 'Alice',
        toUid: 'u2',
        toDisplayName: 'Bob',
        status: FriendRequestStatus.pending,
        createdAt: DateTime(2024),
      );
      final updated = state.copyWith(incomingRequests: [request]);
      expect(updated.incomingRequests, hasLength(1));
      expect(updated.incomingRequests[0].id, 'req-1');
    });

    test('copyWith without arguments preserves all fields', () {
      final friend = Friend(
        friendshipId: 'f1',
        friendUid: 'u2',
        friendDisplayName: 'Bob',
        chatRoomId: 'f1',
        friendedAt: DateTime(2024),
      );
      final state = FriendsState(
        allUsers: [const AppUser(uid: 'u1', displayName: 'Alice')],
        friends: [friend],
        isLoading: true,
        error: 'e',
      );
      final copy = state.copyWith();
      expect(copy.allUsers, hasLength(1));
      expect(copy.friends, hasLength(1));
      expect(copy.isLoading, isTrue);
      expect(copy.error, 'e');
    });

    test('copyWith can clear allUsers to empty list', () {
      final state = FriendsState(
        allUsers: [const AppUser(uid: 'u1', displayName: 'Alice')],
      );
      final cleared = state.copyWith(allUsers: []);
      expect(cleared.allUsers, isEmpty);
    });

    test('initial state has empty enrichment maps', () {
      const state = FriendsState();
      expect(state.presenceMap, isEmpty);
      expect(state.lastMessageMap, isEmpty);
      expect(state.roomMap, isEmpty);
    });

    test('copyWith sets presenceMap', () {
      const state = FriendsState();
      final updated = state.copyWith(
        presenceMap: {'uid1': true, 'uid2': false},
      );
      expect(updated.presenceMap['uid1'], isTrue);
      expect(updated.presenceMap['uid2'], isFalse);
    });

    test('copyWith preserves presenceMap when not provided', () {
      const state = FriendsState(presenceMap: {'uid1': true});
      final updated = state.copyWith(isLoading: true);
      expect(updated.presenceMap['uid1'], isTrue);
    });

    test('copyWith sets lastMessageMap', () {
      const state = FriendsState();
      final updated = state.copyWith(
        lastMessageMap: {'room1': 'hello', 'room2': ''},
      );
      expect(updated.lastMessageMap['room1'], 'hello');
      expect(updated.lastMessageMap['room2'], '');
    });

    test('copyWith preserves lastMessageMap when not provided', () {
      const state = FriendsState(lastMessageMap: {'room1': 'hi'});
      final updated = state.copyWith(isLoading: false);
      expect(updated.lastMessageMap['room1'], 'hi');
    });

    test('copyWith sets roomMap with FriendRoomStatus', () {
      const status = FriendRoomStatus(
        roomId: 'r1',
        memberCount: 2,
        maxUsers: 5,
        isLocked: false,
        mode: 'group',
      );
      const state = FriendsState();
      final updated = state.copyWith(roomMap: {'uid1': status});
      expect(updated.roomMap['uid1']?.roomId, 'r1');
      expect(updated.roomMap['uid1']?.mode, 'group');
    });

    test('copyWith sets roomMap with null value for a key', () {
      const state = FriendsState();
      final updated = state.copyWith(roomMap: {'uid1': null});
      expect(updated.roomMap.containsKey('uid1'), isTrue);
      expect(updated.roomMap['uid1'], isNull);
    });

    test('copyWith preserves roomMap when not provided', () {
      const status = FriendRoomStatus(
        roomId: 'r2',
        memberCount: 1,
        maxUsers: 2,
        isLocked: false,
        mode: '1v1',
      );
      const state = FriendsState(roomMap: {'uid1': status});
      final updated = state.copyWith(isLoading: true);
      expect(updated.roomMap['uid1']?.roomId, 'r2');
    });

    test('copyWith without arguments preserves enrichment maps', () {
      const state = FriendsState(
        presenceMap: {'uid1': true},
        lastMessageMap: {'room1': 'hi'},
        roomMap: {'uid1': null},
      );
      final copy = state.copyWith();
      expect(copy.presenceMap, {'uid1': true});
      expect(copy.lastMessageMap, {'room1': 'hi'});
      expect(copy.roomMap.containsKey('uid1'), isTrue);
    });
  });
}
