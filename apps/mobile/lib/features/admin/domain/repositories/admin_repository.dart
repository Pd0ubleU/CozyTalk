import '../entities/admin_blocked_entry.dart';
import '../entities/admin_dashboard_stats.dart';
import '../entities/admin_report.dart';
import '../entities/admin_user.dart';

abstract class AdminRepository {
  Future<AdminDashboardStats> getDashboardStats();
  Stream<List<AdminReport>> watchReports();
  Future<void> resolveReport(
    String reportId, {
    required String action,
    String? note,
  });
  Future<String> getChatLogUrl(String reportId);
  Stream<List<AdminUser>> watchUsers();
  Future<void> banUser({
    required String uid,
    required String reason,
    required String duration,
    String? note,
    String? reportId,
  });
  Future<void> unbanUser(String uid);
  Future<List<AdminBlockedEntry>> getBlockedUsers(String uid);
}
