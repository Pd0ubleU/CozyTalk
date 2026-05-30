import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend_room_status.dart';
import 'package:mobile/features/friends/domain/usecases/watch_friend_room.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late WatchFriendRoom usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = WatchFriendRoom(repo);
  });

  test('returns null when friend is not in a room', () async {
    final result = await usecase('uid-1').first;
    expect(result, isNull);
  });

  test('returns FriendRoomStatus when friend is in a room', () async {
    repo.roomResult = const FriendRoomStatus(
      roomId: 'abc12',
      memberCount: 3,
      maxUsers: 5,
      isLocked: false,
      mode: 'group',
    );
    final result = await usecase('uid-1').first;
    expect(result, isNotNull);
    expect(result!.roomId, 'abc12');
    expect(result.memberCount, 3);
    expect(result.mode, 'group');
  });

  test('forwards friendUid to repository', () async {
    await usecase('uid-xyz').first;
    expect(repo.lastWatchRoomFriendUid, 'uid-xyz');
  });

  test('propagates stream error from repository', () {
    repo.error = Exception('network error');
    expect(usecase('uid-1').first, throwsA(isA<Exception>()));
  });
}
