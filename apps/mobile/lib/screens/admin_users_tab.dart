import 'package:flutter/material.dart';
import 'admin_shared.dart';

// ─── User Card ───
class AdminUserCard extends StatefulWidget {
  final AdminUser user;
  final int seed;
  final void Function(String action, AdminUser user) onAction;
  const AdminUserCard({
    super.key,
    required this.user,
    required this.seed,
    required this.onAction,
  });

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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              AdminMascotAvatar(seed: widget.seed, size: 48, online: u.online),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(u.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AdminC.ink)),
                      if (u.reports > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: AdminC.red, borderRadius: BorderRadius.circular(999)),
                          child: Text('${u.reports}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.meeting_room_outlined, size: 13, color: AdminC.inkSoft),
                      const SizedBox(width: 4),
                      Text(u.online ? u.room : 'offline', style: const TextStyle(fontSize: 11.5, color: AdminC.inkSoft)),
                      if (u.online && u.session != '—') ...[
                        const SizedBox(width: 10),
                        Icon(Icons.access_time_rounded, size: 13, color: AdminC.inkSoft),
                        const SizedBox(width: 4),
                        Text(u.session, style: const TextStyle(fontSize: 11.5, color: AdminC.inkSoft)),
                      ],
                    ]),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _open = !_open),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: _open ? const Color(0xFFF6EAD0) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.more_horiz_rounded, color: AdminC.brownDarker, size: 20),
                ),
              ),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: AdminC.border.withValues(alpha: .6)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: AdminActionBtn(label: 'Profile', icon: Icons.person_outline_rounded, tone: 'neutral', onTap: () => widget.onAction('view', u))),
              const SizedBox(width: 6),
              Expanded(child: AdminActionBtn(label: 'Kick', icon: Icons.logout_rounded, tone: 'warn', disabled: !u.online, onTap: () => widget.onAction('kick', u))),
              const SizedBox(width: 6),
              Expanded(child: AdminActionBtn(label: 'Ban', icon: Icons.block_rounded, tone: 'danger', onTap: () => widget.onAction('ban', u))),
            ]),
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
  bool _showOffline = false;

  @override
  Widget build(BuildContext context) {
    final list = widget.users
        .where((u) => _showOffline || u.online)
        .where((u) => u.name.toLowerCase().contains(widget.query.toLowerCase()))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF5BBE6B),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF5BBE6B).withValues(alpha: .35), blurRadius: 6, spreadRadius: 2)],
                ),
              ),
              const SizedBox(width: 8),
              RichText(text: TextSpan(
                children: [
                  TextSpan(text: '${widget.onlineCount}', style: const TextStyle(color: AdminC.ink, fontWeight: FontWeight.w800, fontSize: 13)),
                  TextSpan(text: ' users online', style: const TextStyle(color: AdminC.inkSoft, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              )),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showOffline = !_showOffline),
                child: Row(children: [
                  Checkbox(
                    value: _showOffline,
                    onChanged: (v) => setState(() => _showOffline = v!),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    activeColor: AdminC.brownDarker,
                    side: const BorderSide(color: AdminC.inkSoft),
                  ),
                  const Text('show offline', style: TextStyle(fontSize: 12, color: AdminC.inkSoft)),
                ]),
              ),
            ],
          ),
        ),
        ...list.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AdminUserCard(
            user: e.value,
            seed: e.key + 1,
            onAction: widget.onAction,
          ),
        )),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text('No users match "${widget.query}".', style: const TextStyle(color: AdminC.inkSoft, fontSize: 13))),
          ),
      ],
    );
  }
}
