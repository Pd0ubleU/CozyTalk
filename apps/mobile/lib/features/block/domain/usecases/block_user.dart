import '../repositories/block_repository.dart';

class BlockUser {
  final BlockRepository _repository;
  BlockUser(this._repository);
  Future<void> call(String ownerUid, String targetUid, {String? displayName}) =>
      _repository.blockUser(ownerUid, targetUid, displayName: displayName);
}
