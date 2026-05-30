import '../entities/friend_room_status.dart';
import '../repositories/friends_repository.dart';

class WatchFriendRoom {
  final FriendsRepository _repository;
  const WatchFriendRoom(this._repository);

  Stream<FriendRoomStatus?> call(String friendUid) =>
      _repository.watchFriendRoom(friendUid);
}
