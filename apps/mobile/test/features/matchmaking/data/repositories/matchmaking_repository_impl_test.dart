import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/data/datasources/matchmaking_datasource.dart';
import 'package:mobile/features/matchmaking/data/models/room_model.dart';
import 'package:mobile/features/matchmaking/data/repositories/matchmaking_repository_impl.dart';
import 'package:mobile/features/matchmaking/domain/entities/room.dart';

class _FakeMatchmakingDatasource implements MatchmakingDatasource {
  ({String roomId, bool isNewRoom}) joinGroupRoomResult = (
    roomId: 'Ab3Kz',
    isNewRoom: false,
  );
  String createCustomRoomResult = 'XyZ12';
  ({String roomId, RoomMode mode, RoomType roomType}) joinRoomByIdResult = (
    roomId: 'Ab3Kz',
    mode: RoomMode.group,
    roomType: RoomType.custom,
  );
  bool cancel1v1PoolResult = true;
  RoomModel? watchRoomModel;
  Exception? error;

  String? lastLeaveRoomId;
  String? lastJoinRoomByIdArg;
  int join1v1PoolCalls = 0;
  int cancel1v1PoolCalls = 0;
  String? lastSetRoomLockId;
  bool? lastSetRoomLockValue;
  String? lastJoinGroupRoomBackgroundTheme;
  String? lastJoin1v1PoolBackgroundTheme;
  String? lastCreateCustomRoomBackgroundTheme;

  @override
  Future<({String roomId, bool isNewRoom})> joinGroupRoom({
    String? interestText,
    String? backgroundTheme,
  }) async {
    lastJoinGroupRoomBackgroundTheme = backgroundTheme;
    if (error != null) throw error!;
    return joinGroupRoomResult;
  }

  @override
  Future<String> createCustomRoom({String? backgroundTheme}) async {
    lastCreateCustomRoomBackgroundTheme = backgroundTheme;
    if (error != null) throw error!;
    return createCustomRoomResult;
  }

  @override
  Future<({String roomId, RoomMode mode, RoomType roomType})> joinRoomById(
    String roomId,
  ) async {
    lastJoinRoomByIdArg = roomId;
    if (error != null) throw error!;
    return joinRoomByIdResult;
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    lastLeaveRoomId = roomId;
    if (error != null) throw error!;
  }

  @override
  Future<void> join1v1Pool({
    String? interestText,
    String? backgroundTheme,
  }) async {
    join1v1PoolCalls++;
    lastJoin1v1PoolBackgroundTheme = backgroundTheme;
    if (error != null) throw error!;
  }

  @override
  Future<bool> cancel1v1Pool() async {
    cancel1v1PoolCalls++;
    if (error != null) throw error!;
    return cancel1v1PoolResult;
  }

  @override
  Future<void> setRoomLock({
    required String roomId,
    required bool isLocked,
  }) async {
    lastSetRoomLockId = roomId;
    lastSetRoomLockValue = isLocked;
    if (error != null) throw error!;
  }

  @override
  Stream<RoomModel?> watchRoom(String roomId) => Stream.value(watchRoomModel);

  @override
  Stream<String?> watch1v1Match(String uid) => Stream.value(null);

  @override
  Future<void> registerRoomPresence(String roomId) async {}

  @override
  String? getCurrentUserId() => null;
}

void main() {
  late _FakeMatchmakingDatasource ds;
  late MatchmakingRepositoryImpl repo;

  setUp(() {
    ds = _FakeMatchmakingDatasource();
    repo = MatchmakingRepositoryImpl(ds);
  });

  group('MatchmakingRepositoryImpl', () {
    test('joinGroupRoom calls datasource and returns result', () async {
      ds.joinGroupRoomResult = (roomId: 'RR123', isNewRoom: true);

      final result = await repo.joinGroupRoom();

      expect(result.roomId, 'RR123');
      expect(result.isNewRoom, true);
    });

    test('createCustomRoom calls datasource and returns roomId', () async {
      ds.createCustomRoomResult = 'CC456';

      final roomId = await repo.createCustomRoom();

      expect(roomId, 'CC456');
    });

    test('createCustomRoom forwards backgroundTheme to datasource', () async {
      await repo.createCustomRoom(backgroundTheme: 'red_lotus_lake');

      expect(ds.lastCreateCustomRoomBackgroundTheme, 'red_lotus_lake');
    });

    test('createCustomRoom passes null backgroundTheme when omitted', () async {
      await repo.createCustomRoom();

      expect(ds.lastCreateCustomRoomBackgroundTheme, isNull);
    });

    test('joinRoomById passes id to datasource and returns result', () async {
      ds.joinRoomByIdResult = (
        roomId: 'JJ789',
        mode: RoomMode.oneToOne,
        roomType: RoomType.public,
      );

      final result = await repo.joinRoomById('JJ789');

      expect(result.roomId, 'JJ789');
      expect(ds.lastJoinRoomByIdArg, 'JJ789');
    });

    test('leaveRoom calls datasource with correct roomId', () async {
      await repo.leaveRoom('LR111');

      expect(ds.lastLeaveRoomId, 'LR111');
    });

    test('join1v1Pool calls datasource once', () async {
      await repo.join1v1Pool();

      expect(ds.join1v1PoolCalls, 1);
    });

    test('joinGroupRoom forwards backgroundTheme to datasource', () async {
      await repo.joinGroupRoom(backgroundTheme: 'kao_tapu');

      expect(ds.lastJoinGroupRoomBackgroundTheme, 'kao_tapu');
    });

    test('joinGroupRoom passes null backgroundTheme when omitted', () async {
      await repo.joinGroupRoom();

      expect(ds.lastJoinGroupRoomBackgroundTheme, isNull);
    });

    test('join1v1Pool forwards backgroundTheme to datasource', () async {
      await repo.join1v1Pool(backgroundTheme: 'red_lotus_lake');

      expect(ds.lastJoin1v1PoolBackgroundTheme, 'red_lotus_lake');
    });

    test('join1v1Pool passes null backgroundTheme when omitted', () async {
      await repo.join1v1Pool();

      expect(ds.lastJoin1v1PoolBackgroundTheme, isNull);
    });

    test('cancel1v1Pool returns the bool from datasource', () async {
      ds.cancel1v1PoolResult = false;

      final result = await repo.cancel1v1Pool();

      expect(result, false);
      expect(ds.cancel1v1PoolCalls, 1);
    });

    test('setRoomLock passes roomId and isLocked to datasource', () async {
      await repo.setRoomLock(roomId: 'SL222', isLocked: true);

      expect(ds.lastSetRoomLockId, 'SL222');
      expect(ds.lastSetRoomLockValue, true);
    });

    group('watchRoom', () {
      test('emits null when datasource emits null model', () async {
        ds.watchRoomModel = null;

        expect(await repo.watchRoom('WR333').first, isNull);
      });

      test('converts RoomModel to Room entity via toEntity()', () async {
        ds.watchRoomModel = RoomModel.fromJson({
          'roomId': 'WR444',
          'roomType': 'custom',
          'mode': 'group',
          'status': 'active',
          'maxUsers': 5,
          'memberCount': 3,
          'users': ['a', 'b', 'c'],
          'isLocked': true,
          'createdAt': 1700000000000,
          'paddingUntil': null,
        });

        final room = await repo.watchRoom('WR444').first;

        expect(room, isNotNull);
        expect(room!.roomId, 'WR444');
        expect(room.roomType, RoomType.custom);
        expect(room.isLocked, true);
        expect(room.memberCount, 3);
      });
    });

    group('exception propagation', () {
      setUp(() => ds.error = Exception('server error'));

      test('joinGroupRoom propagates exception', () async {
        await expectLater(repo.joinGroupRoom(), throwsA(isA<Exception>()));
      });

      test('createCustomRoom propagates exception', () async {
        await expectLater(repo.createCustomRoom(), throwsA(isA<Exception>()));
      });

      test('joinRoomById propagates exception', () async {
        await expectLater(
          repo.joinRoomById('XX000'),
          throwsA(isA<Exception>()),
        );
      });

      test('leaveRoom propagates exception', () async {
        await expectLater(repo.leaveRoom('XX000'), throwsA(isA<Exception>()));
      });
    });
  });
}
