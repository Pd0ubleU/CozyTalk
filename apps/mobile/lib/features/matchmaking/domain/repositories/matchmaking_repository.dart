import '../entities/room.dart';

abstract class MatchmakingRepository {
  Future<({String roomId, bool isNewRoom})> joinGroupRoom({
    String? interestText,
    String? backgroundTheme,
  });
  Future<String> createCustomRoom({String? backgroundTheme});
  Future<({String roomId, RoomMode mode, RoomType roomType})> joinRoomById(
    String roomId,
  );
  Future<void> leaveRoom(String roomId);
  Future<void> join1v1Pool({String? interestText, String? backgroundTheme});
  Future<bool> cancel1v1Pool();
  Future<void> setRoomLock({required String roomId, required bool isLocked});
  Stream<Room?> watchRoom(String roomId);
  Stream<String?> watch1v1Match(String uid);
}
