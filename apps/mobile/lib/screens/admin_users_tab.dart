import 'package:flutter/material.dart';
import 'admin_shared.dart';
import 'admin_ban_detail_screen.dart';

// ─── User Card ───
class AdminUserCard extends StatefulWidget {
  final AdminUser user;
  final void Function(String action, AdminUser user) onAction;
  const AdminUserCard({super.key, required this.user, required this.onAction});

  @override
  State<AdminUserCard> createState() => _AdminUserCardState();
}

class _AdminUserCardState extends State<AdminUserCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              AdminMascotAvatar(size: 48, online: u.online),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          u.name,
                          style: Theme.of(context).textTheme.bodyLarge!
                              .copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AdminC.ink,
                              ),
                        ),
                        if (u.reports > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AdminC.red,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${u.reports} ${u.reports == 1 ? 'report' : 'reports'}',
                              style: Theme.of(context).textTheme.labelSmall!
                                  .copyWith(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (u.online && u.room != '—') ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 12,
                            color: AdminC.inkSoft,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            u.room,
                            style: Theme.of(context).textTheme.labelSmall!
                                .copyWith(
                                  fontSize: 11.5,
                                  color: AdminC.inkSoft,
                                ),
                          ),
                          if (u.roomId != '—') ...[
                            const SizedBox(width: 4),
                            Text(
                              '· ${u.roomId}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AdminC.inkSoft,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _open = !_open),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _open ? const Color(0xFFF6EAD0) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    color: AdminC.brownDarker,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: AdminC.border.withValues(alpha: .6)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AdminActionBtn(
                    label: 'Profile',
                    icon: Icons.person_outline_rounded,
                    tone: 'neutral',
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black.withValues(alpha: 0.35),
                        builder: (_) => AdminUserProfileDialog(
                          user: u,
                          onViewHistory: u.banHistory.isNotEmpty
                              ? (subject) => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminBanDetailScreen(subject: subject),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AdminActionBtn(
                    label: 'Blocked',
                    icon: Icons.person_off_outlined,
                    tone: 'neutral',
                    onTap: () => widget.onAction('viewBlocked', u),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AdminActionBtn(
                    label: 'Ban',
                    icon: Icons.block_rounded,
                    tone: 'danger',
                    onTap: () => widget.onAction('ban', u),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Users Tab ───
class AdminUsersTab extends StatefulWidget {
  final List<AdminUser> users;
  final String query;
  final int onlineCount;
  final void Function(String action, AdminUser user) onAction;
  const AdminUsersTab({
    super.key,
    required this.users,
    required this.query,
    required this.onlineCount,
    required this.onAction,
  });

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  bool _showOffline = true;

  @override
  Widget build(BuildContext context) {
    final list = widget.users.where((u) => _showOffline || u.online).where((u) {
      final q = widget.query.toLowerCase();
      return u.name.toLowerCase().contains(q) ||
          u.userId.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF5BBE6B),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5BBE6B).withValues(alpha: .35),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${widget.onlineCount}',
                      style: const TextStyle(
                        color: AdminC.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: ' users online',
                      style: const TextStyle(
                        color: AdminC.inkSoft,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showOffline = !_showOffline),
                child: Row(
                  children: [
                    Checkbox(
                      value: _showOffline,
                      onChanged: (v) => setState(() => _showOffline = v!),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      activeColor: AdminC.brownDarker,
                      side: const BorderSide(color: AdminC.inkSoft),
                    ),
                    Text(
                      'show offline',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontSize: 12,
                        color: AdminC.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...list.map(
          (u) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AdminUserCard(user: u, onAction: widget.onAction),
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'No users match "${widget.query}".',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: AdminC.inkSoft,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Admin User Profile Dialog ───
class AdminUserProfileDialog extends StatelessWidget {
  final AdminUser user;
  final void Function(AdminBanDetailSubject)? onViewHistory;
  const AdminUserProfileDialog({
    super.key,
    required this.user,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(context),
                    const SizedBox(width: 16),
                    Expanded(child: _buildInfo(context)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStats(context),
                if (user.banHistory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildBanHistoryRow(context),
                ],
              ],
            ),
            Positioned(
              top: -10,
              right: -10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AdminC.neutral,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AdminC.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Column(
      children: [
        AdminMascotAvatar(size: 72, online: user.online),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 1.25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'UID: ${user.userId}',
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              fontSize: 11,
              color: AdminC.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'USER PROFILE',
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
            fontSize: 11,
            letterSpacing: 0.8,
            color: AdminC.inkSoft,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          user.name,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AdminC.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Interest',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AdminC.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          user.interest.isNotEmpty ? user.interest : '—',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 13,
            color: AdminC.inkSoft,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildBanHistoryRow(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onViewHistory?.call(
          AdminBanDetailSubject(
            name: user.name,
            uid: user.userId,
            online: user.online,
            current: user.banned && user.banHistory.isNotEmpty
                ? user.banHistory.first
                : null,
            previous: user.banned && user.banHistory.length > 1
                ? user.banHistory.sublist(1)
                : (user.banned ? [] : user.banHistory),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AdminC.redSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.block_rounded,
                color: Color(0xFF9F2A18),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ban history',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF9F2A18),
                    ),
                  ),
                  Text(
                    '${user.banHistory.length} previous ban${user.banHistory.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      fontSize: 11.5,
                      color: const Color(0xFF9F2A18),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9F2A18),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AdminC.creamDeep,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _stat(context, '${user.reports}', 'Prior reports', null),
          Container(width: 1, height: 28, color: AdminC.border),
          _stat(context, _accountAge(user.joined), 'Account age', null),
          Container(width: 1, height: 28, color: AdminC.border),
          _stat(
            context,
            user.banned ? 'Banned' : (user.online ? 'Active' : 'Offline'),
            'Status',
            user.banned
                ? AdminC.red
                : (user.online ? AdminC.greenInk : AdminC.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String value,
    String label,
    Color? valueColor,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AdminC.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              fontSize: 11,
              color: AdminC.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Account age helper ───
String _accountAge(String joined) {
  const monthMap = {
    'Jan': 0,
    'Feb': 1,
    'Mar': 2,
    'Apr': 3,
    'May': 4,
    'Jun': 5,
    'Jul': 6,
    'Aug': 7,
    'Sep': 8,
    'Oct': 9,
    'Nov': 10,
    'Dec': 11,
  };
  final parts = joined.split(' ');
  if (parts.length != 2) return joined;
  final mon = monthMap[parts[0]];
  final yr = int.tryParse(parts[1]);
  if (mon == null || yr == null) return joined;
  final now = DateTime.now();
  final diff = (now.year - yr) * 12 + (now.month - 1 - mon);
  if (diff < 1) return '<1m';
  if (diff < 12) return '${diff}m';
  final yrs = diff ~/ 12;
  final rem = diff % 12;
  return rem > 0 ? '${yrs}y ${rem}m' : '${yrs}y';
}
