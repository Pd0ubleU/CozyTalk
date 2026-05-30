import '../../domain/entities/blocked_user.dart';
import '../../domain/repositories/block_repository.dart';
import '../datasources/block_datasource.dart';
import '../models/blocked_user_model.dart';

class BlockRepositoryImpl implements BlockRepository {
  final BlockDatasource _datasource;
  BlockRepositoryImpl(this._datasource);

  @override
  Stream<List<BlockedUser>> watchBlockedUsers(String uid) => _datasource
      .watchBlockedUsers(uid)
      .map((models) => models.map((m) => m.toEntity()).toList());

  @override
  Future<void> blockUser(
    String ownerUid,
    String targetUid, {
    String? displayName,
  }) => _datasource.blockUser(ownerUid, targetUid, displayName: displayName);

  @override
  Future<void> unblockUser(String ownerUid, String targetUid) =>
      _datasource.unblockUser(ownerUid, targetUid);
}
