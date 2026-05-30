import '../../domain/entities/admin_blocked_entry.dart';
import '../../domain/entities/admin_dashboard_stats.dart';
import '../../domain/entities/admin_report.dart';
import '../../domain/entities/admin_user.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_datasource.dart';
import '../models/admin_report_model.dart';
import '../models/admin_user_model.dart';

class AdminRepositoryImpl implements AdminRepository {
  final AdminDatasource _datasource;

  AdminRepositoryImpl(this._datasource);

  @override
  Future<AdminDashboardStats> getDashboardStats() =>
      _datasource.getDashboardStats();

  @override
  Stream<List<AdminReport>> watchReports() => _datasource.watchReports().map(
    (models) => models.map((m) => m.toEntity()).toList(),
  );

  @override
  Future<void> resolveReport(
    String reportId, {
    required String action,
    String? note,
  }) => _datasource.resolveReport(reportId, action: action, note: note);

  @override
  Future<String> getChatLogUrl(String reportId) =>
      _datasource.getChatLogUrl(reportId);

  @override
  Stream<List<AdminUser>> watchUsers() => _datasource.watchUsers().map(
    (models) => models.map((m) => m.toEntity()).toList(),
  );

  @override
  Future<void> banUser({
    required String uid,
    required String reason,
    required String duration,
    String? note,
    String? reportId,
  }) => _datasource.banUser(
    uid: uid,
    reason: reason,
    duration: duration,
    note: note,
    reportId: reportId,
  );

  @override
  Future<void> unbanUser(String uid) => _datasource.unbanUser(uid);

  @override
  Future<List<AdminBlockedEntry>> getBlockedUsers(String uid) =>
      _datasource.getBlockedUsers(uid);
}
