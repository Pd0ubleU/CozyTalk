import 'package:mobile/features/matchmaking/domain/entities/room.dart';
import 'package:mobile/features/matchmaking/domain/repositories/matchmaking_repository.dart';

class FakeMatchmakingRepository implements MatchmakingRepository {
  // ── Configurable return values ──────────────────────────────────────────────

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

  Room? watchRoomValue;

  String? watch1v1MatchValue;

  Exception? error;

  // ── Call tracking ───────────────────────────────────────────────────────────

  int joinGroupRoomCalls = 0;
  int createCustomRoomCalls = 0;
  String? lastJoinRoomByIdArg;
  String? lastLeaveRoomIdArg;
  int join1v1PoolCalls = 0;
  int cancel1v1PoolCalls = 0;
  String? lastSetRoomLockId;
  bool? lastSetRoomLockValue;

  // ── Implementations ─────────────────────────────────────────────────────────

  String? lastJoinGroupRoomInterest;
  String? lastJoinGroupRoomBackgroundTheme;
  String? lastJoin1v1PoolInterest;
  String? lastJoin1v1PoolBackgroundTheme;
  String? lastCreateCustomRoomBackgroundTheme;

  @override
  Future<({String roomId, bool isNewRoom})> joinGroupRoom({
    String? interestText,
    String? backgroundTheme,
  }) async {
    joinGroupRoomCalls++;
    lastJoinGroupRoomInterest = interestText;
    lastJoinGroupRoomBackgroundTheme = backgroundTheme;
    if (error != null) throw error!;
    return joinGroupRoomResult;
  }

  @override
  Future<String> createCustomRoom({String? backgroundTheme}) async {
    createCustomRoomCalls++;
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
    lastLeaveRoomIdArg = roomId;
    if (error != null) throw error!;
  }

  @override
  Future<void> join1v1Pool({
    String? interestText,
    String? backgroundTheme,
  }) async {
    join1v1PoolCalls++;
    lastJoin1v1PoolInterest = interestText;
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
  Stream<Room?> watchRoom(String roomId) => Stream.value(watchRoomValue);

  @override
  Stream<String?> watch1v1Match(String uid) => Stream.value(watch1v1MatchValue);
}

// ── Shared test fixture helpers ────────────────────────────────────────────────

Room makeRoom({
  String roomId = 'Ab3Kz',
  RoomType roomType = RoomType.public,
  RoomMode mode = RoomMode.group,
  RoomStatus status = RoomStatus.active,
  int maxUsers = 5,
  int memberCount = 1,
  List<String>? users,
  bool isLocked = false,
  DateTime? createdAt,
  DateTime? paddingUntil,
}) {
  return Room(
    roomId: roomId,
    roomType: roomType,
    mode: mode,
    status: status,
    maxUsers: maxUsers,
    memberCount: memberCount,
    users: users ?? ['uid1'],
    isLocked: isLocked,
    createdAt: createdAt ?? DateTime(2025),
    paddingUntil: paddingUntil,
  );
}
