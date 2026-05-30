import '../repositories/matchmaking_repository.dart';

class CreateCustomRoom {
  final MatchmakingRepository _repository;
  const CreateCustomRoom(this._repository);

  Future<String> call({String? backgroundTheme}) =>
      _repository.createCustomRoom(backgroundTheme: backgroundTheme);
}
