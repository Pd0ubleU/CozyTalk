import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/usecases/watch_friend_presence.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late WatchFriendPresence usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = WatchFriendPresence(repo);
  });

  test('returns true when friend is online', () async {
    repo.presenceResult = true;
    final result = await usecase('uid-1').first;
    expect(result, isTrue);
  });

  test('returns false when friend is offline', () async {
    final result = await usecase('uid-1').first;
    expect(result, isFalse);
  });

  test('forwards friendUid to repository', () async {
    await usecase('uid-xyz').first;
    expect(repo.lastWatchPresenceFriendUid, 'uid-xyz');
  });

  test('propagates stream error from repository', () {
    repo.error = Exception('connection failed');
    expect(usecase('uid-1').first, throwsA(isA<Exception>()));
  });
}
