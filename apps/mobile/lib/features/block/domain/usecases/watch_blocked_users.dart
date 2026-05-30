import '../entities/blocked_user.dart';
import '../repositories/block_repository.dart';

class WatchBlockedUsers {
  final BlockRepository _repository;
  WatchBlockedUsers(this._repository);
  Stream<List<BlockedUser>> call(String uid) =>
      _repository.watchBlockedUsers(uid);
}
