import '../repositories/matchmaking_repository.dart';

class JoinGroupRoom {
  final MatchmakingRepository _repository;
  const JoinGroupRoom(this._repository);

  Future<({String roomId, bool isNewRoom})> call({
    String? interestText,
    String? backgroundTheme,
  }) => _repository.joinGroupRoom(
    interestText: interestText,
    backgroundTheme: backgroundTheme,
  );
}
