import '../entities/admin_blocked_entry.dart';
import '../repositories/admin_repository.dart';

class GetBlockedUsers {
  final AdminRepository _repository;
  GetBlockedUsers(this._repository);
  Future<List<AdminBlockedEntry>> call(String uid) =>
      _repository.getBlockedUsers(uid);
}
