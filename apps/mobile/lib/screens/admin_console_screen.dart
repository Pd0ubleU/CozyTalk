import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/admin/admin.dart' as feat;
import 'admin_shared.dart';
import 'admin_reports_tab.dart';
import 'admin_users_tab.dart';
import 'admin_banned_tab.dart';
import 'admin_ban_detail_screen.dart';
import 'admin_report_detail_screen.dart';
import 'admin_profile_screen.dart';

// ─── Admin Console Screen ───
class AdminConsoleScreen extends ConsumerStatefulWidget {
  const AdminConsoleScreen({super.key});
  @override
  ConsumerState<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends ConsumerState<AdminConsoleScreen> {
  int _tab = 0; // 0=Reports 1=Users 2=Banned
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _toastMsg;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showToast(String msg) {
    setState(() => _toastMsg = msg);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toastMsg = null);
    });
  }

  void _openReport(AdminReport displayReport) async {
    final reportsNotifier = ref.read(feat.adminReportsProvider.notifier);
    final usersState = ref.read(feat.adminUsersProvider);
    final reporterEntity = usersState.users
        .where((u) => u.uid == displayReport.reporterId)
        .firstOrNull;
    final reporterUser = reporterEntity != null
        ? _toDisplayUser(reporterEntity)
        : null;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminReportDetailScreen(
          report: displayReport,
          reporterUser: reporterUser,
          onDismiss: () async {
            await reportsNotifier.resolveReport(
              displayReport.id,
              action: 'dismiss',
            );
            if (mounted) _showToast('Report dismissed');
          },
          onBanConfirmed: (reason, duration, note) async {
            await ref
                .read(feat.adminUsersProvider.notifier)
                .banUser(
                  uid: displayReport.reportedUserId,
                  reason: reason,
                  duration: _normalizeDuration(duration),
                  note: note.trim().isEmpty ? null : note.trim(),
                  reportId: displayReport.id,
                );
            if (mounted) _showToast('User banned');
          },
          onGetChatLog: displayReport.chatLogStoragePath != null
              ? () => reportsNotifier.getChatLogUrl(displayReport.id)
              : null,
        ),
      ),
    );
  }

  // ─── Mapping helpers ───

  static String _normalizeDuration(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower == '1 day') return '1 Day';
    if (lower == '7 days') return '7 Days';
    if (lower == '30 days') return '30 Days';
    if (lower == 'permanent') return 'Permanent';
    throw ArgumentError('Unknown ban duration: $raw');
  }

  static String _reportTypeLabel(String type) {
    switch (type) {
      case 'spam':
        return 'Spam & Scams';
      case 'harassment':
        return 'Harassment or Bullying';
      case 'inappropriate_content':
        return 'Inappropriate Content';
      default:
        return 'Others';
    }
  }

  static String _reportTypeSeverity(String type) {
    switch (type) {
      case 'harassment':
      case 'spam':
        return 'high';
      case 'inappropriate_content':
        return 'med';
      default:
        return 'low';
    }
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  static String _formatJoined(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  AdminReport _toDisplayReport(feat.AdminReport e) {
    return AdminReport(
      id: e.id,
      status: e.status,
      reporter: e.reporterName,
      reported: e.reportedName,
      reasons: [_reportTypeLabel(e.reportType)],
      context: e.reason,
      time: _formatTime(e.createdAt),
      evidence: e.contextImageUrls.length,
      contextImageUrls: e.contextImageUrls,
      chatLogStoragePath: e.chatLogStoragePath,
      severity: _reportTypeSeverity(e.reportType),
      room: '',
      roomId: e.sessionId,
      reportedUserId: e.reportedUserId,
      reportedInterest: e.reportedInterest,
      reporterId: e.reporterId,
      outcome: e.outcome == null
          ? null
          : AdminReportOutcome(
              kind: e.outcome!.kind,
              label: e.outcome!.kind == 'banned'
                  ? 'Banned'
                  : e.outcome!.kind == 'dismissed'
                  ? 'Dismissed'
                  : 'Reviewed',
              by: e.outcome!.byName,
            ),
    );
  }

  AdminUser _toDisplayUser(feat.AdminUser e, {int reportCount = 0}) {
    return AdminUser(
      id: e.uid,
      userId: e.uid,
      name: e.displayName,
      interest: e.interest,
      online: e.online,
      banned: e.banned,
      room: e.online ? 'In room' : '',
      roomId: '',
      session: e.online ? 'Active' : 'Offline',
      reports: reportCount,
      joined: _formatJoined(e.createdAt),
      banHistory: e.banHistory.map(_toDisplayBanRecord).toList(),
    );
  }

  BannedUser _toBannedUser(feat.AdminUser e, {int reportCount = 0}) {
    return BannedUser(
      id: e.uid,
      name: e.displayName,
      uid: e.uid,
      reason: e.banReason ?? '',
      duration: e.banDuration ?? '',
      date: e.bannedAt != null ? _formatDate(e.bannedAt!) : '',
      expires: e.banExpiresAt != null ? _formatDate(e.banExpiresAt!) : 'Never',
      by: e.bannedByName ?? '',
      note: e.banNote ?? '',
      reportRefs: const [],
      previous: e.banHistory.map(_toDisplayBanRecord).toList(),
      interest: e.interest,
      reports: reportCount,
      joined: _formatJoined(e.createdAt),
    );
  }

  AdminBanRecord _toDisplayBanRecord(feat.AdminBanRecord r) {
    return AdminBanRecord(
      reason: r.reason,
      duration: r.duration,
      date: _formatDate(r.bannedAt),
      by: r.bannedByName,
      note: r.note ?? '',
      expires: r.expiresAt != null ? _formatDate(r.expiresAt!) : null,
    );
  }

  AdminBanDetailSubject _toBanDetailSubject(
    feat.AdminUser e, {
    int reportCount = 0,
  }) {
    final currentBan = e.banned
        ? AdminBanRecord(
            reason: e.banReason ?? '',
            duration: e.banDuration ?? '',
            date: e.bannedAt != null ? _formatDate(e.bannedAt!) : '',
            by: e.bannedByName ?? '',
            note: e.banNote ?? '',
            expires: e.banExpiresAt != null
                ? _formatDate(e.banExpiresAt!)
                : null,
          )
        : null;
    return AdminBanDetailSubject(
      name: e.displayName,
      uid: e.uid,
      online: e.online,
      interest: e.interest,
      reports: reportCount,
      joined: _formatJoined(e.createdAt),
      current: currentBan,
      reportRefs: const [],
      previous: e.banHistory.map(_toDisplayBanRecord).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(feat.adminDashboardProvider);
    final reportsState = ref.watch(feat.adminReportsProvider);
    final usersState = ref.watch(feat.adminUsersProvider);

    final reportCounts = <String, int>{};
    for (final r in reportsState.reports) {
      reportCounts[r.reportedUserId] =
          (reportCounts[r.reportedUserId] ?? 0) + 1;
    }

    final reports = reportsState.reports.map(_toDisplayReport).toList();
    final users = usersState.users
        .where((u) => !u.banned)
        .map((e) => _toDisplayUser(e, reportCount: reportCounts[e.uid] ?? 0))
        .toList();
    final banned = usersState.users
        .where((u) => u.banned)
        .map((e) => _toBannedUser(e, reportCount: reportCounts[e.uid] ?? 0))
        .toList();

    final pendingCount =
        dashAsync.value?.pendingReports ??
        reportsState.reports.where((r) => r.status == 'pending').length;
    final onlineCount = usersState.users.where((u) => u.online).length;
    final bannedCount = dashAsync.value?.bannedUsers ?? banned.length;

    return Scaffold(
      backgroundColor: AdminC.cream,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(
                reports: reports,
                reportsState: reportsState,
                usersState: usersState,
                pendingCount: pendingCount,
                onlineCount: onlineCount,
                bannedCount: bannedCount,
              ),
              _buildTabs(pendingCount: pendingCount),
              _buildSearchBar(),
              Expanded(
                child: _buildBody(
                  reports: reports,
                  users: users,
                  banned: banned,
                  usersState: usersState,
                  onlineCount: onlineCount,
                  reportCounts: reportCounts,
                ),
              ),
            ],
          ),
          if (_toastMsg != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 40,
              right: 40,
              child: AdminToast(msg: _toastMsg!),
            ),
        ],
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader({
    required List<AdminReport> reports,
    required feat.AdminReportsState reportsState,
    required feat.AdminUsersState usersState,
    required int pendingCount,
    required int onlineCount,
    required int bannedCount,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: AdminC.brown,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 18,
        20,
        18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E2),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/Logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ADMIN CONSOLE',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: .7),
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Text(
                    'Moderation',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminProfileScreen(
                      resolvedCount: reportsState.reports
                          .where((r) => r.status == 'resolved')
                          .length,
                      bansCount: usersState.users.fold<int>(
                        0,
                        (sum, u) => sum + u.banHistory.length,
                      ),
                    ),
                  ),
                ),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person,
                    color: AdminC.brownDarker,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Pending reports',
                  value: '$pendingCount',
                  accentColor: AdminC.red,
                  icon: Icons.flag_rounded,
                  pulse: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Users online',
                  value: '$onlineCount',
                  accentColor: const Color(0xFF5BBE6B),
                  icon: Icons.people_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Active bans',
                  value: '$bannedCount',
                  accentColor: AdminC.brownDarker,
                  icon: Icons.block_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Tabs ───
  Widget _buildTabs({required int pendingCount}) {
    final tabs = [
      (icon: Icons.flag_rounded, label: 'Reports', badge: pendingCount),
      (icon: Icons.people_rounded, label: 'Users', badge: 0),
      (icon: Icons.block_rounded, label: 'Banned', badge: 0),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = _tab == i;
            final t = tabs[i];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? AdminC.green : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        t.icon,
                        size: 16,
                        color: active ? AdminC.greenInk : AdminC.inkSoft,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active ? AdminC.greenInk : AdminC.inkSoft,
                        ),
                      ),
                      if (t.badge > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AdminC.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${t.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── Search bar ───
  Widget _buildSearchBar() {
    final hints = [
      'Search reports by user…',
      'Search users…',
      'Search banned users…',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: AdminC.inkSoft, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: hints[_tab],
                  hintStyle: const TextStyle(
                    color: AdminC.inkSoft,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14, color: AdminC.ink),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () => _searchCtrl.clear(),
                child: Icon(
                  Icons.close_rounded,
                  color: AdminC.inkSoft,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Body ───
  Widget _buildBody({
    required List<AdminReport> reports,
    required List<AdminUser> users,
    required List<BannedUser> banned,
    required feat.AdminUsersState usersState,
    required int onlineCount,
    required Map<String, int> reportCounts,
  }) {
    return switch (_tab) {
      0 => AdminReportsTab(
        reports: reports,
        onOpen: _openReport,
        query: _query,
      ),
      1 => AdminUsersTab(
        users: users,
        query: _query,
        onlineCount: onlineCount,
        onAction: (action, displayUser) async {
          if (action != 'ban') return;
          final entity = usersState.users
              .where((u) => u.uid == displayUser.userId)
              .firstOrNull;
          if (entity == null) return;
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => AdminBanModal(
              username: entity.displayName,
              onClose: () => Navigator.pop(context),
              onConfirm: (_, reason, duration) async {
                await ref
                    .read(feat.adminUsersProvider.notifier)
                    .banUser(
                      uid: entity.uid,
                      reason: reason,
                      duration: _normalizeDuration(duration),
                      reportId: null,
                    );
                if (mounted) _showToast('User banned');
              },
            ),
          );
        },
      ),
      _ => AdminBannedTab(
        banned: banned,
        query: _query,
        onOpen: (bannedUser) {
          final entity = usersState.users
              .where((u) => u.uid == bannedUser.uid)
              .firstOrNull;
          if (entity == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminBanDetailScreen(
                subject: _toBanDetailSubject(
                  entity,
                  reportCount: reportCounts[entity.uid] ?? 0,
                ),
                onUnban: (subject) async {
                  await ref
                      .read(feat.adminUsersProvider.notifier)
                      .unbanUser(subject.uid);
                  if (mounted) {
                    Navigator.pop(context);
                    _showToast('User unbanned');
                  }
                },
              ),
            ),
          );
        },
      ),
    };
  }
}

// ─── Stat Card (header-only widget) ───
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final IconData icon;
  final bool pulse;
  const _StatCard({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.icon,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AdminC.ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AdminC.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
