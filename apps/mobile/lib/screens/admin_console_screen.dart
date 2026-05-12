import 'package:flutter/material.dart';
import 'admin_shared.dart';
import 'admin_reports_tab.dart';
import 'admin_users_tab.dart';
import 'admin_banned_tab.dart';
import 'admin_report_detail_screen.dart';
import 'admin_profile_screen.dart';

// ─── Admin Console Screen ───
class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});
  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  int _tab = 0; // 0=Reports 1=Users 2=Banned
  final _searchCtrl = TextEditingController();
  String _query = '';

  final List<AdminReport> _reports = [
    AdminReport(id: 'r1', status: 'pending',  reporter: 'Somtum',    reported: 'PhakYou',    reasons: ['Harassment or Bullying'],                        context: "He kept sending mean messages and called me names after I said I didn't want to keep chatting.", time: '3m ago',    evidence: 2, severity: 'high', room: 'Kao Tapu',       roomId: 'AWD3V'),
    AdminReport(id: 'r2', status: 'pending',  reporter: 'Mitsuru',   reported: 'TrueLove99', reasons: ['Spam & Scams'],                                   context: 'Sent me a link to a sketchy site asking for my phone number and bank info.',                        time: '18m ago',  evidence: 1, severity: 'high', room: 'Red Lotus Lake', roomId: 'BLK7R'),
    AdminReport(id: 'r3', status: 'pending',  reporter: 'KaiTom',    reported: 'NongPrae',   reasons: ['Exposing private identifying information'],         context: 'Posted my full name and school in the group chat without my permission.',                          time: '42m ago',  evidence: 3, severity: 'med',  room: 'Sea of Cloud',   roomId: 'CXP2M'),
    AdminReport(id: 'r4', status: 'pending',  reporter: 'Platoo',    reported: 'Somjeed',    reasons: ['Others'],                                          context: 'Was being weirdly aggressive but nothing specific yet.',                                            time: '1h ago',   evidence: 0, severity: 'low',  room: 'Lumphini Park',  roomId: 'DYQ9T'),
    AdminReport(id: 'r5', status: 'pending',  reporter: 'Anonymous', reported: 'CoolGuy42',  reasons: ['Harassment or Bullying', 'Others'],                context: 'Repeatedly DMs after being told no.',                                                              time: '2h ago',   evidence: 1, severity: 'med',  room: 'Kao Tapu',       roomId: 'EZN4W'),
    AdminReport(id: 'r6', status: 'resolved', reporter: 'NongPrae',  reported: 'SpamBot7',   reasons: ['Spam & Scams'],                                   context: 'Crypto giveaway scam.',                                                                             time: 'Yesterday', evidence: 2, severity: 'high', room: 'Red Lotus Lake', roomId: 'FXJ6S'),
  ];

  final List<AdminUser> _users = [
    AdminUser(id: 'u1',  name: 'Somtum',     online: true,  room: 'Kao Tapu',       session: '42m',    reports: 0, joined: 'Mar 2026'),
    AdminUser(id: 'u2',  name: 'PhakYou',    online: true,  room: 'Kao Tapu',       session: '1h 12m', reports: 3, joined: 'Apr 2026'),
    AdminUser(id: 'u3',  name: 'Mitsuru',    online: true,  room: 'Red Lotus Lake', session: '18m',    reports: 0, joined: 'Jan 2026'),
    AdminUser(id: 'u4',  name: 'KaiTom',     online: true,  room: 'Sea of Cloud',   session: '2h 03m', reports: 1, joined: 'Feb 2026'),
    AdminUser(id: 'u5',  name: 'NongPrae',   online: true,  room: 'Sea of Cloud',   session: '33m',    reports: 2, joined: 'Dec 2025'),
    AdminUser(id: 'u6',  name: 'Platoo',     online: false, room: '—',              session: '—',      reports: 0, joined: 'Mar 2026'),
    AdminUser(id: 'u7',  name: 'Somjeed',    online: true,  room: 'Lumphini Park',  session: '8m',     reports: 1, joined: 'May 2026'),
    AdminUser(id: 'u8',  name: 'TrueLove99', online: true,  room: 'Red Lotus Lake', session: '24m',    reports: 4, joined: 'Apr 2026'),
    AdminUser(id: 'u9',  name: 'CoolGuy42',  online: true,  room: 'Kao Tapu',       session: '1h 47m', reports: 2, joined: 'Feb 2026'),
    AdminUser(id: 'u10', name: 'Seksan',     online: false, room: '—',              session: '—',      reports: 0, joined: 'Jan 2026'),
  ];

  final List<BannedUser> _banned = [
    BannedUser(id: 'b1', name: 'SpamBot7', reason: 'Spam & Scams',                            duration: 'Permanent', date: 'Yesterday', by: 'admin@cozytalk'),
    BannedUser(id: 'b2', name: 'ToxicTed', reason: 'Harassment or Bullying',                  duration: '30 days',   date: '2 May',     by: 'admin@cozytalk'),
    BannedUser(id: 'b3', name: 'LeakyLou', reason: 'Exposing private identifying information', duration: 'Permanent', date: '28 Apr',    by: 'admin@cozytalk'),
  ];

  AdminUser? _banUser;
  AdminReport? _banFromReport;
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

  void _openReport(AdminReport r) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AdminReportDetailScreen(
        report: r,
        onDismiss: () {
          setState(() => r.status = 'resolved');
          _showToast('Report dismissed');
        },
        onBanRequested: () {
          _banFromReport = r;
          setState(() => _banUser = AdminUser(
            id: r.id, name: r.reported, online: false, room: '—', session: '—', reports: 0, joined: '',
          ));
        },
      ),
    ));
  }

  void _doBan(String name, String reason, String duration) {
    setState(() {
      _banned.insert(0, BannedUser(
        id: 'b-${DateTime.now().millisecondsSinceEpoch}',
        name: name, reason: reason, duration: duration,
        date: 'Just now', by: 'admin@cozytalk',
      ));
      if (_banFromReport != null) {
        _banFromReport!.status = 'resolved';
        _banFromReport = null;
      }
      for (final u in _users) {
        if (u.name == name) { u.online = false; u.room = '—'; u.session = '—'; }
      }
      _banUser = null;
    });
    _showToast('$name banned · $duration');
  }

  int get _pendingCount => _reports.where((r) => r.status == 'pending').length;
  int get _onlineCount  => _users.where((u) => u.online).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminC.cream,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              _buildTabs(),
              _buildSearchBar(),
              Expanded(child: _buildBody()),
            ],
          ),
          if (_banUser != null)
            AdminBanModal(
              username: _banUser!.name,
              onClose: () => setState(() { _banUser = null; _banFromReport = null; }),
              onConfirm: _doBan,
            ),
          if (_toastMsg != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 40, right: 40,
              child: AdminToast(msg: _toastMsg!),
            ),
        ],
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: AdminC.brown,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E2),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset('assets/images/Logo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ADMIN CONSOLE', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: .7), letterSpacing: 1.4)),
                  const Text('Moderation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProfileScreen())),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Icon(Icons.person, color: AdminC.brownDarker, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Pending reports', value: '$_pendingCount', accentColor: AdminC.red, icon: Icons.flag_rounded, pulse: true)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: 'Users online', value: '$_onlineCount', accentColor: const Color(0xFF5BBE6B), icon: Icons.people_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: 'Active bans', value: '${_banned.length}', accentColor: AdminC.brownDarker, icon: Icons.block_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Tabs ───
  Widget _buildTabs() {
    final tabs = [
      (icon: Icons.flag_rounded,   label: 'Reports', badge: _pendingCount),
      (icon: Icons.people_rounded, label: 'Users',   badge: 0),
      (icon: Icons.block_rounded,  label: 'Banned',  badge: 0),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0, 4))],
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
                      Icon(t.icon, size: 16, color: active ? AdminC.greenInk : AdminC.inkSoft),
                      const SizedBox(width: 5),
                      Text(t.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? AdminC.greenInk : AdminC.inkSoft)),
                      if (t.badge > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: AdminC.red, borderRadius: BorderRadius.circular(999)),
                          child: Text('${t.badge}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
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
    final hints = ['Search reports by user…', 'Search users…', 'Search banned users…'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 10, offset: const Offset(0, 3))],
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
                  hintStyle: const TextStyle(color: AdminC.inkSoft, fontSize: 14),
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
                child: Icon(Icons.close_rounded, color: AdminC.inkSoft, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Body ───
  Widget _buildBody() {
    return switch (_tab) {
      0 => AdminReportsTab(reports: _reports, onOpen: _openReport, query: _query),
      1 => AdminUsersTab(
          users: _users,
          query: _query,
          onlineCount: _onlineCount,
          onAction: (action, user) {
            if (action == 'ban') {
              setState(() => _banUser = user);
            } else if (action == 'kick') {
              setState(() { user.online = false; user.room = '—'; user.session = '—'; });
              _showToast('${user.name} kicked');
            } else {
              _showToast("Opening ${user.name}'s profile…");
            }
          },
        ),
      _ => AdminBannedTab(
          banned: _banned,
          query: _query,
          onUnban: (b) {
            setState(() => _banned.removeWhere((x) => x.id == b.id));
            _showToast('${b.name} unbanned');
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
  const _StatCard({required this.label, required this.value, required this.accentColor, required this.icon, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AdminC.ink)),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AdminC.inkSoft)),
        ],
      ),
    );
  }
}
