import '../repositories/block_repository.dart';

class UnblockUser {
  final BlockRepository _repository;
  UnblockUser(this._repository);
  Future<void> call(String ownerUid, String targetUid) =>
      _repository.unblockUser(ownerUid, targetUid);
}
