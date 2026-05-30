import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/block/domain/entities/blocked_user.dart';
import 'package:mobile/features/block/domain/repositories/block_repository.dart';
import 'package:mobile/features/block/domain/usecases/watch_blocked_users.dart';

class _FakeBlockRepository implements BlockRepository {
  Stream<List<BlockedUser>> Function(String uid)? watchFactory;
  Exception? error;

  @override
  Stream<List<BlockedUser>> watchBlockedUsers(String uid) =>
      watchFactory != null ? watchFactory!(uid) : const Stream.empty();

  @override
  Future<void> blockUser(
    String ownerUid,
    String targetUid, {
    String? displayName,
  }) async {
    if (error != null) throw error!;
  }

  @override
  Future<void> unblockUser(String ownerUid, String targetUid) async {
    if (error != null) throw error!;
  }
}

void main() {
  late _FakeBlockRepository repository;
  late WatchBlockedUsers usecase;

  setUp(() {
    repository = _FakeBlockRepository();
    usecase = WatchBlockedUsers(repository);
  });

  group('WatchBlockedUsers', () {
    test('forwards the stream returned by the repository', () async {
      final ts = DateTime(2024, 1, 15);
      final expected = [BlockedUser(uid: 'uid-1', blockedAt: ts)];
      repository.watchFactory = (_) => Stream.value(expected);

      final result = await usecase.call('owner-uid').first;
      expect(result.length, 1);
      expect(result.first.uid, 'uid-1');
    });

    test('passes the uid argument to the repository', () async {
      String? capturedUid;
      repository.watchFactory = (uid) {
        capturedUid = uid;
        return const Stream.empty();
      };

      usecase.call('test-uid');
      expect(capturedUid, 'test-uid');
    });

    test('emits multiple events as repository stream emits', () async {
      final ts = DateTime(2024, 1, 15);
      final first = [BlockedUser(uid: 'a', blockedAt: ts)];
      final second = [
        BlockedUser(uid: 'a', blockedAt: ts),
        BlockedUser(uid: 'b', blockedAt: ts),
      ];
      final controller = StreamController<List<BlockedUser>>();
      repository.watchFactory = (_) => controller.stream;

      final emitted = <List<BlockedUser>>[];
      final sub = usecase.call('owner').listen(emitted.add);

      controller.add(first);
      controller.add(second);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await controller.close();

      expect(emitted.length, 2);
      expect(emitted[0].length, 1);
      expect(emitted[1].length, 2);
    });

    test('emits empty list when repository emits empty list', () async {
      repository.watchFactory = (_) => Stream.value([]);
      final result = await usecase.call('owner').first;
      expect(result, isEmpty);
    });
  });
}
