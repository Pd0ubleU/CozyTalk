import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/block/data/datasources/block_datasource.dart';
import 'package:mobile/features/block/data/models/blocked_user_model.dart';
import 'package:mobile/features/block/data/repositories/block_repository_impl.dart';

class _FakeBlockDatasource implements BlockDatasource {
  int blockCount = 0;
  int unblockCount = 0;
  String? lastOwnerUid;
  String? lastTargetUid;
  String? lastDisplayName;
  Exception? error;

  Stream<List<BlockedUserModel>> Function(String uid)? watchFactory;

  @override
  Stream<List<BlockedUserModel>> watchBlockedUsers(String uid) =>
      watchFactory != null ? watchFactory!(uid) : const Stream.empty();

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
  Future<void> unblockUser(String ownerUid, String targetUid) async {
    unblockCount++;
    lastOwnerUid = ownerUid;
    lastTargetUid = targetUid;
    if (error != null) throw error!;
  }
}

final _ts = DateTime(2024, 1, 15);

BlockedUserModel _makeModel(String uid, {String? displayName}) =>
    BlockedUserModel(blockedUid: uid, displayName: displayName, blockedAt: _ts);

void main() {
  late _FakeBlockDatasource datasource;
  late BlockRepositoryImpl repository;

  setUp(() {
    datasource = _FakeBlockDatasource();
    repository = BlockRepositoryImpl(datasource);
  });

  group('BlockRepositoryImpl', () {
    group('watchBlockedUsers', () {
      test('maps models to entities via stream', () async {
        datasource.watchFactory = (_) => Stream.value([
          _makeModel('uid-1', displayName: 'Alice'),
          _makeModel('uid-2'),
        ]);
        final entities = await repository.watchBlockedUsers('owner').first;
        expect(entities.length, 2);
        expect(entities[0].uid, 'uid-1');
        expect(entities[0].displayName, 'Alice');
        expect(entities[1].uid, 'uid-2');
        expect(entities[1].displayName, isNull);
      });

      test('emits empty list when datasource emits empty list', () async {
        datasource.watchFactory = (_) => Stream.value([]);
        final entities = await repository.watchBlockedUsers('owner').first;
        expect(entities, isEmpty);
      });

      test('passes uid to datasource', () async {
        String? capturedUid;
        datasource.watchFactory = (uid) {
          capturedUid = uid;
          return const Stream.empty();
        };
        repository.watchBlockedUsers('my-uid');
        expect(capturedUid, 'my-uid');
      });

      test('maps blockedAt field correctly', () async {
        datasource.watchFactory = (_) => Stream.value([_makeModel('uid-3')]);
        final entities = await repository.watchBlockedUsers('owner').first;
        expect(entities.first.blockedAt, _ts);
      });
    });

    group('blockUser', () {
      test('delegates to datasource', () async {
        await repository.blockUser('owner-1', 'target-1');
        expect(datasource.blockCount, 1);
        expect(datasource.lastOwnerUid, 'owner-1');
        expect(datasource.lastTargetUid, 'target-1');
      });

      test('forwards displayName to datasource', () async {
        await repository.blockUser('o', 't', displayName: 'Eve');
        expect(datasource.lastDisplayName, 'Eve');
      });

      test('passes null displayName when not provided', () async {
        await repository.blockUser('o', 't');
        expect(datasource.lastDisplayName, isNull);
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('block failed');
        expect(() => repository.blockUser('o', 't'), throwsA(isA<Exception>()));
      });
    });

    group('unblockUser', () {
      test('delegates to datasource', () async {
        await repository.unblockUser('owner-1', 'target-1');
        expect(datasource.unblockCount, 1);
        expect(datasource.lastOwnerUid, 'owner-1');
        expect(datasource.lastTargetUid, 'target-1');
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('unblock failed');
        expect(
          () => repository.unblockUser('o', 't'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
