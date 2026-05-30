import '../repositories/friends_repository.dart';

class WatchFriendPresence {
  final FriendsRepository _repository;
  const WatchFriendPresence(this._repository);

  Stream<bool> call(String friendUid) =>
      _repository.watchFriendPresence(friendUid);
}
