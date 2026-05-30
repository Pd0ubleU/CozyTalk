import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/admin_datasource.dart';
import '../../data/repositories/admin_repository_impl.dart';
import '../../domain/entities/admin_blocked_entry.dart';
import '../../domain/entities/admin_dashboard_stats.dart';
import '../../domain/entities/admin_report.dart';
import '../../domain/entities/admin_user.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/ban_user.dart';
import '../../domain/usecases/get_blocked_users.dart';
import '../../domain/usecases/get_chat_log_url.dart';
import '../../domain/usecases/get_dashboard_stats.dart';
import '../../domain/usecases/resolve_report.dart';
import '../../domain/usecases/unban_user.dart';
import '../../domain/usecases/watch_reports.dart';
import '../../domain/usecases/watch_users.dart';

const _sentinel = Object();

// ── DI wiring ──────────────────────────────────────────────────────────────

final _adminDatasourceProvider = Provider<AdminDatasource>((ref) {
  final ds = AdminDatasourceImpl(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: 'us-central1'),
  );
  ref.onDispose(ds.dispose);
  return ds;
});

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepositoryImpl(ref.watch(_adminDatasourceProvider)),
);

final _getDashboardStatsProvider = Provider<GetDashboardStats>(
  (ref) => GetDashboardStats(ref.watch(adminRepositoryProvider)),
);

final _watchReportsProvider = Provider<WatchReports>(
  (ref) => WatchReports(ref.watch(adminRepositoryProvider)),
);

final _resolveReportProvider = Provider<ResolveReport>(
  (ref) => ResolveReport(ref.watch(adminRepositoryProvider)),
);

final _getChatLogUrlProvider = Provider<GetChatLogUrl>(
  (ref) => GetChatLogUrl(ref.watch(adminRepositoryProvider)),
);

final _watchUsersProvider = Provider<WatchUsers>(
  (ref) => WatchUsers(ref.watch(adminRepositoryProvider)),
);

final _banUserProvider = Provider<BanUser>(
  (ref) => BanUser(ref.watch(adminRepositoryProvider)),
);

final _unbanUserProvider = Provider<UnbanUser>(
  (ref) => UnbanUser(ref.watch(adminRepositoryProvider)),
);

final _getBlockedUsersProvider = Provider<GetBlockedUsers>(
  (ref) => GetBlockedUsers(ref.watch(adminRepositoryProvider)),
);

// ── Public providers ───────────────────────────────────────────────────────

final adminDashboardProvider =
    AsyncNotifierProvider<AdminDashboardNotifier, AdminDashboardStats>(
      AdminDashboardNotifier.new,
    );

final adminReportsProvider =
    NotifierProvider<AdminReportsNotifier, AdminReportsState>(
      AdminReportsNotifier.new,
    );

final adminUsersProvider =
    NotifierProvider<AdminUsersNotifier, AdminUsersState>(
      AdminUsersNotifier.new,
    );

// ── Dashboard ──────────────────────────────────────────────────────────────

class AdminDashboardNotifier extends AsyncNotifier<AdminDashboardStats> {
  @override
  Future<AdminDashboardStats> build() =>
      ref.read(_getDashboardStatsProvider).call();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(_getDashboardStatsProvider).call(),
    );
  }
}

// ── Reports ────────────────────────────────────────────────────────────────

enum AdminReportsStatus { idle, loading, loaded, error }

class AdminReportsState {
  final AdminReportsStatus status;
  final List<AdminReport> reports;
  final bool isSubmitting;
  final String? error;
  final String? actionError;
  final String? chatLogUrl;

  const AdminReportsState({
    this.status = AdminReportsStatus.idle,
    this.reports = const [],
    this.isSubmitting = false,
    this.error,
    this.actionError,
    this.chatLogUrl,
  });

  AdminReportsState copyWith({
    AdminReportsStatus? status,
    List<AdminReport>? reports,
    bool? isSubmitting,
    Object? error = _sentinel,
    Object? actionError = _sentinel,
    Object? chatLogUrl = _sentinel,
  }) => AdminReportsState(
    status: status ?? this.status,
    reports: reports ?? this.reports,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    error: error == _sentinel ? this.error : error as String?,
    actionError: actionError == _sentinel
        ? this.actionError
        : actionError as String?,
    chatLogUrl: chatLogUrl == _sentinel
        ? this.chatLogUrl
        : chatLogUrl as String?,
  );
}

class AdminReportsNotifier extends Notifier<AdminReportsState> {
  StreamSubscription<List<AdminReport>>? _sub;

  @override
  AdminReportsState build() {
    ref.onDispose(() => _sub?.cancel());
    _sub = ref
        .read(_watchReportsProvider)
        .call()
        .listen(
          (reports) {
            state = state.copyWith(
              status: AdminReportsStatus.loaded,
              reports: reports,
              error: null,
            );
          },
          onError: (Object e) {
            state = state.copyWith(
              status: AdminReportsStatus.error,
              error: e.toString(),
            );
          },
        );
    return const AdminReportsState(status: AdminReportsStatus.loading);
  }

  Future<void> resolveReport(
    String reportId, {
    required String action,
    String? note,
  }) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, actionError: null);
    try {
      await ref
          .read(_resolveReportProvider)
          .call(reportId, action: action, note: note);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, actionError: e.toString());
    }
  }

  Future<String?> getChatLogUrl(String reportId) async {
    if (state.isSubmitting) return null;
    state = state.copyWith(
      isSubmitting: true,
      actionError: null,
      chatLogUrl: null,
    );
    try {
      final url = await ref.read(_getChatLogUrlProvider).call(reportId);
      state = state.copyWith(isSubmitting: false, chatLogUrl: url);
      return url;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, actionError: e.toString());
      return null;
    }
  }
}

// ── Users ──────────────────────────────────────────────────────────────────

enum AdminUsersStatus { idle, loading, loaded, error }

class AdminUsersState {
  final AdminUsersStatus status;
  final List<AdminUser> users;
  final bool isSubmitting;
  final String? error;
  final String? actionError;
  final List<AdminBlockedEntry>? blockedUsersForUid;
  final String? blockedUsersUid;

  const AdminUsersState({
    this.status = AdminUsersStatus.idle,
    this.users = const [],
    this.isSubmitting = false,
    this.error,
    this.actionError,
    this.blockedUsersForUid,
    this.blockedUsersUid,
  });

  AdminUsersState copyWith({
    AdminUsersStatus? status,
    List<AdminUser>? users,
    bool? isSubmitting,
    Object? error = _sentinel,
    Object? actionError = _sentinel,
    Object? blockedUsersForUid = _sentinel,
    Object? blockedUsersUid = _sentinel,
  }) => AdminUsersState(
    status: status ?? this.status,
    users: users ?? this.users,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    error: error == _sentinel ? this.error : error as String?,
    actionError: actionError == _sentinel
        ? this.actionError
        : actionError as String?,
    blockedUsersForUid: blockedUsersForUid == _sentinel
        ? this.blockedUsersForUid
        : blockedUsersForUid as List<AdminBlockedEntry>?,
    blockedUsersUid: blockedUsersUid == _sentinel
        ? this.blockedUsersUid
        : blockedUsersUid as String?,
  );
}

class AdminUsersNotifier extends Notifier<AdminUsersState> {
  StreamSubscription<List<AdminUser>>? _sub;

  @override
  AdminUsersState build() {
    ref.onDispose(() => _sub?.cancel());
    _sub = ref
        .read(_watchUsersProvider)
        .call()
        .listen(
          (users) {
            state = state.copyWith(
              status: AdminUsersStatus.loaded,
              users: users,
              error: null,
            );
          },
          onError: (Object e) {
            state = state.copyWith(
              status: AdminUsersStatus.error,
              error: e.toString(),
            );
          },
        );
    return const AdminUsersState(status: AdminUsersStatus.loading);
  }

  Future<void> banUser({
    required String uid,
    required String reason,
    required String duration,
    String? note,
    String? reportId,
  }) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, actionError: null);
    try {
      await ref
          .read(_banUserProvider)
          .call(
            uid: uid,
            reason: reason,
            duration: duration,
            note: note,
            reportId: reportId,
          );
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, actionError: e.toString());
    }
  }

  Future<void> unbanUser(String uid) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, actionError: null);
    try {
      await ref.read(_unbanUserProvider).call(uid);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, actionError: e.toString());
    }
  }

  Future<void> loadBlockedUsers(String uid) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, actionError: null);
    try {
      final entries = await ref.read(_getBlockedUsersProvider).call(uid);
      state = state.copyWith(
        isSubmitting: false,
        blockedUsersUid: uid,
        blockedUsersForUid: entries,
      );
    } catch (e) {
      state = state.copyWith(isSubmitting: false, actionError: e.toString());
    }
  }
}
