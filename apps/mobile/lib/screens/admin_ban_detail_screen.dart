import 'package:flutter/material.dart';
import 'admin_shared.dart';
import '../shared/layered_avatar.dart';

class AdminBanDetailScreen extends StatelessWidget {
  final AdminBanDetailSubject subject;
  final void Function(AdminBanDetailSubject)? onUnban;

  const AdminBanDetailScreen({super.key, required this.subject, this.onUnban});

  @override
  Widget build(BuildContext context) {
    final s = subject;
    final hasCurrent = s.current != null;

    return Scaffold(
      backgroundColor: AdminC.cream,
      body: Column(
        children: [
          _buildPageHeader(context, hasCurrent, s),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _buildSubjectCard(context, s, hasCurrent),
                if (hasCurrent) ...[
                  const SizedBox(height: 12),
                  _sectionLabel(context, 'Current ban'),
                  _buildBanRecord(context, s.current!, current: true),
                ],
                if (s.previous.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _sectionLabel(
                    context,
                    'Previous bans (${s.previous.length})',
                  ),
                  ...s.previous.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildBanRecord(context, p, current: false),
                    ),
                  ),
                ],
                if (!hasCurrent && s.previous.isEmpty)
                  _buildEmptyState(context),
              ],
            ),
          ),
          if (hasCurrent && onUnban != null) _buildUnbanButton(context, s),
        ],
      ),
    );
  }

  Widget _buildPageHeader(
    BuildContext context,
    bool hasCurrent,
    AdminBanDetailSubject s,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: AdminC.brown,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + 22,
        18,
        28,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
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
              child: const Icon(
                Icons.chevron_left_rounded,
                color: AdminC.brownDarker,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasCurrent ? 'Ban Detail' : 'Ban History',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -.3,
                ),
              ),
              Text(
                hasCurrent
                    ? 'Banned · ${s.current!.date}'
                    : '${s.previous.length} previous ban${s.previous.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: .75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(
    BuildContext context,
    AdminBanDetailSubject s,
    bool hasCurrent,
  ) {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar + UID badge ──
              Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(child: LayeredAvatar(boxSize: 56)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'UID: ${s.uid}',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        fontSize: 10,
                        color: AdminC.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // ── Info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCurrent ? 'BANNED USER' : 'USER',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminC.inkSoft,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.name,
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AdminC.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Interest',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AdminC.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.interest.isNotEmpty ? s.interest : '—',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontSize: 12,
                        color: AdminC.inkSoft,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Stats bar ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AdminC.creamDeep,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _statCell(context, '${s.reports}', 'Prior reports', null),
                Container(width: 1, height: 30, color: AdminC.border),
                _statCell(
                  context,
                  s.joined.isNotEmpty ? _accountAge(s.joined) : '—',
                  'Account age',
                  null,
                ),
                Container(width: 1, height: 30, color: AdminC.border),
                _statCell(
                  context,
                  hasCurrent ? 'Banned' : (s.online ? 'Active' : 'Offline'),
                  'Status',
                  hasCurrent
                      ? AdminC.red
                      : (s.online ? AdminC.greenInk : AdminC.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(
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

  static String _accountAge(String joined) {
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

  Widget _sectionLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AdminC.ink,
      ),
    ),
  );

  Widget _buildBanRecord(
    BuildContext context,
    AdminBanRecord rec, {
    required bool current,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: current
            ? const Border(left: BorderSide(color: AdminC.red, width: 4))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (current) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AdminC.red,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'CURRENT',
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  rec.reason,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AdminC.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AdminC.brownDarker,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  rec.duration,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: const Color(0xFFFFF7E8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            rec.date,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              fontSize: 11.5,
              color: AdminC.inkSoft,
            ),
          ),
          if (rec.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminC.creamDeep,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                rec.note,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  fontSize: 12.5,
                  color: AdminC.ink,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'by ',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        fontSize: 11,
                        color: AdminC.inkSoft,
                      ),
                    ),
                    TextSpan(
                      text: rec.by,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminC.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (current && rec.expires != null && rec.expires != '—')
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'expires ',
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          fontSize: 11,
                          color: AdminC.inkSoft,
                        ),
                      ),
                      TextSpan(
                        text: rec.expires,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AdminC.ink,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.shield_rounded,
              color: AdminC.brownDarker,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              'No ban history. Clean record ✨',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: AdminC.inkSoft,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnbanButton(BuildContext context, AdminBanDetailSubject s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AdminC.cream, AdminC.cream.withValues(alpha: 0)],
          stops: const [.6, 1],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: AdminModalBtn(
          label: 'Unban ${s.name}',
          bg: AdminC.green,
          fg: AdminC.greenInk,
          onTap: () => showAdminConfirmUnban(
            context: context,
            username: s.name,
            onConfirm: () {
              onUnban!(s);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}
