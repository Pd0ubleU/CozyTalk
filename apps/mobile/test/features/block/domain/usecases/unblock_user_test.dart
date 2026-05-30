import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/block/domain/entities/blocked_user.dart';
import 'package:mobile/features/block/domain/repositories/block_repository.dart';
import 'package:mobile/features/block/domain/usecases/unblock_user.dart';

class _FakeBlockRepository implements BlockRepository {
  int unblockCount = 0;
  String? lastOwnerUid;
  String? lastTargetUid;
  Exception? error;

  @override
  Future<void> unblockUser(String ownerUid, String targetUid) async {
    unblockCount++;
    lastOwnerUid = ownerUid;
    lastTargetUid = targetUid;
    if (error != null) throw error!;
  }

  @override
  Future<void> blockUser(
    String ownerUid,
    String targetUid, {
    String? displayName,
  }) async {}

  @override
  Stream<List<BlockedUser>> watchBlockedUsers(String uid) =>
      const Stream.empty();
}

void main() {
  late _FakeBlockRepository repository;
  late UnblockUser usecase;

  setUp(() {
    repository = _FakeBlockRepository();
    usecase = UnblockUser(repository);
  });

  group('UnblockUser', () {
    test('delegates to the repository with ownerUid and targetUid', () async {
      await usecase.call('owner-1', 'target-1');
      expect(repository.unblockCount, 1);
      expect(repository.lastOwnerUid, 'owner-1');
      expect(repository.lastTargetUid, 'target-1');
    });

    test('propagates repository exception', () {
      repository.error = Exception('not blocked');
      expect(
        () => usecase.call('owner-1', 'target-1'),
        throwsA(isA<Exception>()),
      );
    });

    test('calls repository exactly once per call', () async {
      await usecase.call('o', 't');
      await usecase.call('o', 't2');
      expect(repository.unblockCount, 2);
    });

    test('forwards both uid arguments correctly', () async {
      await usecase.call('owner-abc', 'target-xyz');
      expect(repository.lastOwnerUid, 'owner-abc');
      expect(repository.lastTargetUid, 'target-xyz');
    });
  });
}
