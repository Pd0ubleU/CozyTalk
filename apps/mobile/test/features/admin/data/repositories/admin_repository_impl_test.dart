import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/data/datasources/admin_datasource.dart';
import 'package:mobile/features/admin/data/models/admin_report_model.dart';
import 'package:mobile/features/admin/data/models/admin_user_model.dart';
import 'package:mobile/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:mobile/features/admin/domain/entities/admin_blocked_entry.dart';
import 'package:mobile/features/admin/domain/entities/admin_dashboard_stats.dart';

class _FakeAdminDatasource implements AdminDatasource {
  AdminDashboardStats? returnStats;
  List<AdminReportModel>? returnReports;
  String? returnChatLogUrl;
  List<AdminUserModel>? returnUsers;
  Exception? error;

  int getDashboardStatsCount = 0;
  int watchReportsCount = 0;
  int resolveReportCount = 0;
  int getChatLogUrlCount = 0;
  int watchUsersCount = 0;
  int banUserCount = 0;
  int unbanUserCount = 0;

  String? lastReportId;
  String? lastAction;
  String? lastNote;
  String? lastUid;
  String? lastReason;
  String? lastDuration;
  String? lastBanNote;
  String? lastReportIdForBan;

  @override
  Future<AdminDashboardStats> getDashboardStats() async {
    getDashboardStatsCount++;
    if (error != null) throw error!;
    return returnStats!;
  }

  @override
  Stream<List<AdminReportModel>> watchReports() {
    watchReportsCount++;
    if (error != null) return Stream.error(error!);
    return Stream.value(returnReports ?? []);
  }

  @override
  Future<void> resolveReport(
    String reportId, {
    required String action,
    String? note,
  }) async {
    resolveReportCount++;
    lastReportId = reportId;
    lastAction = action;
    lastNote = note;
    if (error != null) throw error!;
  }

  @override
  Future<String> getChatLogUrl(String reportId) async {
    getChatLogUrlCount++;
    lastReportId = reportId;
    if (error != null) throw error!;
    return returnChatLogUrl!;
  }

  @override
  Stream<List<AdminUserModel>> watchUsers() {
    watchUsersCount++;
    if (error != null) return Stream.error(error!);
    return Stream.value(returnUsers ?? []);
  }

  @override
  Future<void> banUser({
    required String uid,
    required String reason,
    required String duration,
    String? note,
    String? reportId,
  }) async {
    banUserCount++;
    lastUid = uid;
    lastReason = reason;
    lastDuration = duration;
    lastBanNote = note;
    lastReportIdForBan = reportId;
    if (error != null) throw error!;
  }

  @override
  Future<void> unbanUser(String uid) async {
    unbanUserCount++;
    lastUid = uid;
    if (error != null) throw error!;
  }

  @override
  void dispose() {}

  @override
  Future<List<AdminBlockedEntry>> getBlockedUsers(String uid) async {
    if (error != null) throw error!;
    return [];
  }
}

AdminReportModel _makeReportModel(String id) => AdminReportModel.fromJson({
  'id': id,
  'reporterId': 'u1',
  'reportedUserId': 'u2',
  'sessionId': 's1',
  'reportType': 'spam',
  'reason': 'Test',
  'createdAt': '2025-01-15T00:00:00.000Z',
});

AdminUserModel _makeUserModel(String uid) => AdminUserModel.fromJson({
  'uid': uid,
  'displayName': 'Alice',
  'createdAt': '2024-06-01T00:00:00.000Z',
});

void main() {
  late _FakeAdminDatasource datasource;
  late AdminRepositoryImpl repository;

  setUp(() {
    datasource = _FakeAdminDatasource();
    repository = AdminRepositoryImpl(datasource);
  });

  group('AdminRepositoryImpl', () {
    group('getDashboardStats', () {
      test('delegates to datasource and returns stats', () async {
        datasource.returnStats = const AdminDashboardStats(
          pendingReports: 2,
          onlineUsers: 5,
          bannedUsers: 1,
        );
        final result = await repository.getDashboardStats();
        expect(datasource.getDashboardStatsCount, 1);
        expect(result.pendingReports, 2);
        expect(result.onlineUsers, 5);
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('network error');
        expect(() => repository.getDashboardStats(), throwsA(isA<Exception>()));
      });
    });

    group('watchReports', () {
      test('converts report models to entities', () async {
        datasource.returnReports = [_makeReportModel('r1')];
        final list = await repository.watchReports().first;
        expect(datasource.watchReportsCount, 1);
        expect(list.length, 1);
        expect(list.first.id, 'r1');
      });

      test('returns empty list when datasource returns empty', () async {
        datasource.returnReports = [];
        final list = await repository.watchReports().first;
        expect(list, isEmpty);
      });
    });

    group('resolveReport', () {
      test('calls datasource with correct args', () async {
        await repository.resolveReport('r1', action: 'dismiss', note: 'ok');
        expect(datasource.resolveReportCount, 1);
        expect(datasource.lastReportId, 'r1');
        expect(datasource.lastAction, 'dismiss');
        expect(datasource.lastNote, 'ok');
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('not found');
        expect(
          () => repository.resolveReport('r1', action: 'dismiss'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getChatLogUrl', () {
      test('calls datasource and returns url', () async {
        datasource.returnChatLogUrl = 'https://example.com/url';
        final url = await repository.getChatLogUrl('r1');
        expect(datasource.getChatLogUrlCount, 1);
        expect(url, 'https://example.com/url');
      });
    });

    group('watchUsers', () {
      test('converts user models to entities', () async {
        datasource.returnUsers = [_makeUserModel('u1')];
        final list = await repository.watchUsers().first;
        expect(datasource.watchUsersCount, 1);
        expect(list.length, 1);
        expect(list.first.uid, 'u1');
      });
    });

    group('banUser', () {
      test('calls datasource with all args', () async {
        await repository.banUser(
          uid: 'u1',
          reason: 'Spam',
          duration: '7 Days',
          note: 'Note',
          reportId: 'r1',
        );
        expect(datasource.banUserCount, 1);
        expect(datasource.lastUid, 'u1');
        expect(datasource.lastReason, 'Spam');
        expect(datasource.lastDuration, '7 Days');
        expect(datasource.lastBanNote, 'Note');
        expect(datasource.lastReportIdForBan, 'r1');
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('already banned');
        expect(
          () =>
              repository.banUser(uid: 'u1', reason: 'Spam', duration: '1 Day'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('unbanUser', () {
      test('calls datasource with uid', () async {
        await repository.unbanUser('u1');
        expect(datasource.unbanUserCount, 1);
        expect(datasource.lastUid, 'u1');
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('not banned');
        expect(() => repository.unbanUser('u1'), throwsA(isA<Exception>()));
      });
    });
  });
}
