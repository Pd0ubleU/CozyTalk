import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/block/domain/entities/blocked_user.dart';
import 'package:mobile/features/block/domain/repositories/block_repository.dart';
import 'package:mobile/features/block/domain/usecases/block_user.dart';

class _FakeBlockRepository implements BlockRepository {
  int blockCount = 0;
  String? lastOwnerUid;
  String? lastTargetUid;
  String? lastDisplayName;
  Exception? error;

  @override
  Future<void> blockUser(
    String ownerUid,
    String targetUid, {
    String? displayName,
  }) async {
    blockCount++;
    lastOwnerUid = ownerUid;
    lastTargetUid = targetUid;
    lastDisplayName = displayName;
    if (error != null) throw error!;
  }

  @override
  Future<void> unblockUser(String ownerUid, String targetUid) async {}

  @override
  Stream<List<BlockedUser>> watchBlockedUsers(String uid) =>
      const Stream.empty();
}

void main() {
  late _FakeBlockRepository repository;
  late BlockUser usecase;

  setUp(() {
    repository = _FakeBlockRepository();
    usecase = BlockUser(repository);
  });

  group('BlockUser', () {
    test('delegates to the repository with ownerUid and targetUid', () async {
      await usecase.call('owner-1', 'target-1');
      expect(repository.blockCount, 1);
      expect(repository.lastOwnerUid, 'owner-1');
      expect(repository.lastTargetUid, 'target-1');
    });

    test('forwards optional displayName to the repository', () async {
      await usecase.call('owner-1', 'target-1', displayName: 'Bob');
      expect(repository.lastDisplayName, 'Bob');
    });

    test('passes null displayName when not provided', () async {
      await usecase.call('owner-1', 'target-1');
      expect(repository.lastDisplayName, isNull);
    });

    test('propagates repository exception', () {
      repository.error = Exception('already blocked');
      expect(
        () => usecase.call('owner-1', 'target-1'),
        throwsA(isA<Exception>()),
      );
    });

    test('calls repository exactly once per call', () async {
      await usecase.call('o', 't');
      await usecase.call('o', 't2');
      expect(repository.blockCount, 2);
    });
  });
}
