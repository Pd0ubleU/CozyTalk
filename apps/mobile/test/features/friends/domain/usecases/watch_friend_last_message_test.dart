import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/usecases/watch_friend_last_message.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late WatchFriendLastMessage usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = WatchFriendLastMessage(repo);
  });

  test('returns last message text from repository', () async {
    repo.lastMessageResult = 'hey there';
    final result = await usecase('room-1').first;
    expect(result, 'hey there');
  });

  test('returns empty string when no messages', () async {
    final result = await usecase('room-1').first;
    expect(result, '');
  });

  test('forwards chatRoomId to repository', () async {
    await usecase('room-abc').first;
    expect(repo.lastWatchLastMessageChatRoomId, 'room-abc');
  });

  test('propagates stream error from repository', () {
    repo.error = Exception('permission denied');
    expect(usecase('room-1').first, throwsA(isA<Exception>()));
  });
}
