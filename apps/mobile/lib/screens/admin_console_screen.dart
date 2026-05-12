import 'package:flutter/material.dart';
import 'admin_report_detail_screen.dart';
import 'admin_profile_screen.dart';

// ─── Design tokens (matches admin.jsx palette) ───
class _C {
  static const brown      = Color(0xFF6E5B57);
  static const brownDarker= Color(0xFF3F3230);
  static const cream      = Color(0xFFFBF4E5);
  static const creamDeep  = Color(0xFFF6EAD0);
  static const green      = Color(0xFFD6E8B4);
  static const greenInk   = Color(0xFF3F4E1F);
  static const red        = Color(0xFFD85542);
  static const redSoft    = Color(0xFFF1DDD7);
  static const neutral    = Color(0xFFD8D2C8);
  static const ink        = Color(0xFF1F1A18);
  static const inkSoft    = Color(0xFF6B5F5A);
  static const border     = Color(0xFFEDE3CE);
}

// ─── Data models ───
class AdminReport {
  final String id;
  String status;
  final String reporter;
  final String reported;
  final List<String> reasons;
  final String context;
  final String time;
  final int evidence;
  final String severity;
  final String room;

  AdminReport({
    required this.id,
    required this.status,
    required this.reporter,
    required this.reported,
    required this.reasons,
    required this.context,
    required this.time,
    required this.evidence,
    required this.severity,
    required this.room,
  });
}

class AdminUser {
  final String id;
  final String name;
  bool online;
  String room;
  String session;
  final int reports;
  final String joined;

  AdminUser({
    required this.id,
    required this.name,
    required this.online,
    required this.room,
    required this.session,
    required this.reports,
    required this.joined,
  });
}

class BannedUser {
  final String id;
  final String name;
  final String reason;
  final String duration;
  final String date;
  final String by;

  BannedUser({
    required this.id,
    required this.name,
    required this.reason,
    required this.duration,
    required this.date,
    required this.by,
  });
}

const _banReasons = [
  'Harassment or Bullying',
  'Spam & Scams',
  'Exposing private identifying information',
  'Others',
];

// ─── Severity chip ───
class _SeverityChip extends StatelessWidget {
  final String severity;
  const _SeverityChip(this.severity);

  @override
  Widget build(BuildContext context) {
    final map = {
      'high': (bg: const Color(0xFFFBDDD6), fg: const Color(0xFF9F2A18), label: 'HIGH'),
      'med':  (bg: const Color(0xFFFAE7C8), fg: const Color(0xFF8A5A14), label: 'MED'),
      'low':  (bg: const Color(0xFFE4EAD3), fg: const Color(0xFF4F5E27), label: 'LOW'),
    }[severity]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: map.bg, borderRadius: BorderRadius.circular(999)),
      child: Text(map.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: map.fg, letterSpacing: .6)),
    );
  }
}

// ─── Pixel-style mascot avatar ───
const _mascotBgs = [
  Color(0xFFF4D6BE), Color(0xFFE2D8F0), Color(0xFFD4E9D6),
  Color(0xFFFAE3C9), Color(0xFFE9D2C9), Color(0xFFCFDEEA),
  Color(0xFFF5DFDF), Color(0xFFDEE6CF), Color(0xFFE7D6BB),
];

class _MascotAvatar extends StatelessWidget {
  final int seed;
  final double size;
  final bool? online;
  const _MascotAvatar({required this.seed, this.size = 48, this.online});

  @override
  Widget build(BuildContext context) {
    final bg = _mascotBgs[seed % _mascotBgs.length];
    return Stack(
      children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Center(
            child: Icon(Icons.person, color: _C.brownDarker, size: size * 0.55),
          ),
        ),
        if (online != null)
          Positioned(
            right: 2, bottom: 2,
            child: Container(
              width: size * .22, height: size * .22,
              decoration: BoxDecoration(
                color: online! ? const Color(0xFF5BBE6B) : const Color(0xFFB5ADA4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

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
    AdminReport(id:'r1', status:'pending', reporter:'Somtum', reported:'PhakYou', reasons:['Harassment or Bullying'], context:"He kept sending mean messages and called me names after I said I didn't want to keep chatting.", time:'3m ago', evidence:2, severity:'high', room:'Kao Tapu'),
    AdminReport(id:'r2', status:'pending', reporter:'Mitsuru', reported:'TrueLove99', reasons:['Spam & Scams'], context:'Sent me a link to a sketchy site asking for my phone number and bank info.', time:'18m ago', evidence:1, severity:'high', room:'Red Lotus Lake'),
    AdminReport(id:'r3', status:'pending', reporter:'KaiTom', reported:'NongPrae', reasons:['Exposing private identifying information'], context:'Posted my full name and school in the group chat without my permission.', time:'42m ago', evidence:3, severity:'med', room:'Sea of Cloud'),
    AdminReport(id:'r4', status:'pending', reporter:'Platoo', reported:'Somjeed', reasons:['Others'], context:'Was being weirdly aggressive but nothing specific yet.', time:'1h ago', evidence:0, severity:'low', room:'Lumphini Park'),
    AdminReport(id:'r5', status:'pending', reporter:'Anonymous', reported:'CoolGuy42', reasons:['Harassment or Bullying','Others'], context:'Repeatedly DMs after being told no.', time:'2h ago', evidence:1, severity:'med', room:'Kao Tapu'),
    AdminReport(id:'r6', status:'resolved', reporter:'NongPrae', reported:'SpamBot7', reasons:['Spam & Scams'], context:'Crypto giveaway scam.', time:'Yesterday', evidence:2, severity:'high', room:'Red Lotus Lake'),
  ];

  final List<AdminUser> _users = [
    AdminUser(id:'u1', name:'Somtum',     online:true,  room:'Kao Tapu',      session:'42m',    reports:0, joined:'Mar 2026'),
    AdminUser(id:'u2', name:'PhakYou',    online:true,  room:'Kao Tapu',      session:'1h 12m', reports:3, joined:'Apr 2026'),
    AdminUser(id:'u3', name:'Mitsuru',    online:true,  room:'Red Lotus Lake',session:'18m',    reports:0, joined:'Jan 2026'),
    AdminUser(id:'u4', name:'KaiTom',     online:true,  room:'Sea of Cloud',  session:'2h 03m', reports:1, joined:'Feb 2026'),
    AdminUser(id:'u5', name:'NongPrae',   online:true,  room:'Sea of Cloud',  session:'33m',    reports:2, joined:'Dec 2025'),
    AdminUser(id:'u6', name:'Platoo',     online:false, room:'—',             session:'—',      reports:0, joined:'Mar 2026'),
    AdminUser(id:'u7', name:'Somjeed',    online:true,  room:'Lumphini Park', session:'8m',     reports:1, joined:'May 2026'),
    AdminUser(id:'u8', name:'TrueLove99', online:true,  room:'Red Lotus Lake',session:'24m',    reports:4, joined:'Apr 2026'),
    AdminUser(id:'u9', name:'CoolGuy42',  online:true,  room:'Kao Tapu',      session:'1h 47m', reports:2, joined:'Feb 2026'),
    AdminUser(id:'u10',name:'Seksan',     online:false, room:'—',             session:'—',      reports:0, joined:'Jan 2026'),
  ];

  final List<BannedUser> _banned = [
    BannedUser(id:'b1', name:'SpamBot7',  reason:'Spam & Scams',                            duration:'Permanent', date:'Yesterday', by:'admin@cozytalk'),
    BannedUser(id:'b2', name:'ToxicTed',  reason:'Harassment or Bullying',                  duration:'30 days',   date:'2 May',     by:'admin@cozytalk'),
    BannedUser(id:'b3', name:'LeakyLou',  reason:'Exposing private identifying information', duration:'Permanent', date:'28 Apr',    by:'admin@cozytalk'),
  ];

  // Ban modal state
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
      backgroundColor: _C.cream,
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
            _BanModal(
              username: _banUser!.name,
              onClose: () => setState(() { _banUser = null; _banFromReport = null; }),
              onConfirm: _doBan,
            ),
          if (_toastMsg != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 40, right: 40,
              child: _Toast(msg: _toastMsg!),
            ),
        ],
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _C.brown,
        borderRadius: BorderRadius.vertical(top: Radius.circular(0), bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo mark
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: const Color(0xFFFFF6E2), borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 4, offset: const Offset(0,2))]),
                child: Center(
                  child: Text('CT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _C.brownDarker)),
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
              // Profile button
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProfileScreen())),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 4, offset: const Offset(0,2))]),
                  child: Icon(Icons.person, color: _C.brownDarker, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Stat cards
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Pending reports', value: '$_pendingCount', accentColor: _C.red, icon: Icons.flag_rounded, pulse: true)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: 'Users online', value: '$_onlineCount', accentColor: const Color(0xFF5BBE6B), icon: Icons.people_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: 'Active bans', value: '${_banned.length}', accentColor: _C.brownDarker, icon: Icons.block_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Tabs ───
  Widget _buildTabs() {
    final tabs = [
      (icon: Icons.flag_rounded, label: 'Reports', badge: _pendingCount),
      (icon: Icons.people_rounded, label: 'Users',   badge: 0),
      (icon: Icons.block_rounded,  label: 'Banned',  badge: 0),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0,4))],
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
                    color: active ? _C.green : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.icon, size: 16, color: active ? _C.greenInk : _C.inkSoft),
                      const SizedBox(width: 5),
                      Text(t.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? _C.greenInk : _C.inkSoft)),
                      if (t.badge > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: _C.red, borderRadius: BorderRadius.circular(999)),
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 10, offset: const Offset(0,3))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: _C.inkSoft, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: hints[_tab],
                  hintStyle: TextStyle(color: _C.inkSoft, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14, color: _C.ink),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () => _searchCtrl.clear(),
                child: Icon(Icons.close_rounded, color: _C.inkSoft, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Body ───
  Widget _buildBody() {
    return switch (_tab) {
      0 => _buildReportsTab(),
      1 => _buildUsersTab(),
      _ => _buildBannedTab(),
    };
  }

  // ─── Reports Tab ───
  String _reportFilter = 'pending';

  Widget _buildReportsTab() {
    final filtered = _reports.where((r) {
      final matchFilter = _reportFilter == 'all' ? true : r.status == _reportFilter;
      final matchQuery = r.reported.toLowerCase().contains(_query.toLowerCase()) ||
          r.reporter.toLowerCase().contains(_query.toLowerCase());
      return matchFilter && matchQuery;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 6,
            children: [['pending','Pending'],['resolved','Resolved'],['all','All']].map((e) {
              final active = _reportFilter == e[0];
              return GestureDetector(
                onTap: () => setState(() => _reportFilter = e[0]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? _C.brownDarker : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: active ? null : Border.all(color: _C.border, width: 1.5),
                  ),
                  child: Text(e[1], style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: active ? const Color(0xFFFFF6E2) : _C.inkSoft,
                  )),
                ),
              );
            }).toList(),
          ),
        ),
        ...filtered.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ReportCard(report: e.value, seed: e.key + 2, onTap: () => _openReport(e.value)),
        )),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text('No reports here. 🌿', style: TextStyle(color: _C.inkSoft, fontSize: 13))),
          ),
      ],
    );
  }

  // ─── Users Tab ───
  bool _showOffline = false;

  Widget _buildUsersTab() {
    final list = _users
        .where((u) => (_showOffline || u.online))
        .where((u) => u.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(width: 10, height: 10,
                decoration: BoxDecoration(color: const Color(0xFF5BBE6B), shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF5BBE6B).withValues(alpha: .35), blurRadius: 6, spreadRadius: 2)]),
              ),
              const SizedBox(width: 8),
              RichText(text: TextSpan(
                children: [
                  TextSpan(text: '$_onlineCount', style: const TextStyle(color: _C.ink, fontWeight: FontWeight.w800, fontSize: 13)),
                  TextSpan(text: ' users online', style: TextStyle(color: _C.inkSoft, fontWeight: FontWeight.w600, fontSize: 13)),
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
                    activeColor: _C.brownDarker,
                    side: BorderSide(color: _C.inkSoft),
                  ),
                  Text('show offline', style: TextStyle(fontSize: 12, color: _C.inkSoft)),
                ]),
              ),
            ],
          ),
        ),
        ...list.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _UserCard(
            user: e.value, seed: e.key + 1,
            onAction: (action) {
              if (action == 'ban') {
                setState(() => _banUser = e.value);
              } else if (action == 'kick') {
                setState(() { e.value.online = false; e.value.room = '—'; e.value.session = '—'; });
                _showToast('${e.value.name} kicked');
              } else {
                _showToast("Opening ${e.value.name}'s profile…");
              }
            },
          ),
        )),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text('No users match "$_query".', style: TextStyle(color: _C.inkSoft, fontSize: 13))),
          ),
      ],
    );
  }

  // ─── Banned Tab ───
  Widget _buildBannedTab() {
    final list = _banned.where((b) => b.name.toLowerCase().contains(_query.toLowerCase())).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RichText(text: TextSpan(children: [
            TextSpan(text: '${_banned.length}', style: const TextStyle(color: _C.ink, fontWeight: FontWeight.w800, fontSize: 13)),
            TextSpan(text: ' active bans', style: TextStyle(color: _C.inkSoft, fontWeight: FontWeight.w600, fontSize: 13)),
          ])),
        ),
        ...list.map((b) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _BannedCard(
            banned: b,
            onUnban: () {
              setState(() => _banned.removeWhere((x) => x.id == b.id));
              _showToast('${b.name} unbanned');
            },
          ),
        )),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text('No bans match "$_query".', style: TextStyle(color: _C.inkSoft, fontSize: 13))),
          ),
      ],
    );
  }
}

// ─── Stat Card ───
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 4, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: accentColor),
            if (pulse) ...[
              const SizedBox(width: 4),
              Container(width: 6, height: 6,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
            ],
          ]),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _C.ink)),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _C.inkSoft)),
        ],
      ),
    );
  }
}

// ─── Report Card ───
class _ReportCard extends StatelessWidget {
  final AdminReport report;
  final int seed;
  final VoidCallback onTap;
  const _ReportCard({required this.report, required this.seed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0,4))],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MascotAvatar(seed: seed, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(spacing: 6, children: [
                          Text(report.reported, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _C.ink)),
                          _SeverityChip(report.severity),
                        ]),
                      ),
                      Text(report.time, style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  RichText(text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: _C.inkSoft),
                    children: [
                      const TextSpan(text: 'reported by '),
                      TextSpan(text: report.reporter, style: const TextStyle(fontWeight: FontWeight.w700, color: _C.ink)),
                    ],
                  )),
                  const SizedBox(height: 8),
                  Wrap(spacing: 4, runSpacing: 4, children: report.reasons.map((r) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFF6EAD0), borderRadius: BorderRadius.circular(999)),
                    child: Text(r, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.brownDarker)),
                  )).toList()),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.meeting_room_outlined, size: 14, color: _C.inkSoft),
                    const SizedBox(width: 4),
                    Text(report.room, style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
                    if (report.evidence > 0) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.image_outlined, size: 14, color: _C.inkSoft),
                      const SizedBox(width: 4),
                      Text('${report.evidence} attachment${report.evidence > 1 ? 's' : ''}', style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── User Card ───
class _UserCard extends StatefulWidget {
  final AdminUser user;
  final int seed;
  final void Function(String action) onAction;
  const _UserCard({required this.user, required this.seed, required this.onAction});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0,4))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              _MascotAvatar(seed: widget.seed, size: 48, online: u.online),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(u.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _C.ink)),
                      if (u.reports > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: _C.red, borderRadius: BorderRadius.circular(999)),
                          child: Text('${u.reports}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.meeting_room_outlined, size: 13, color: _C.inkSoft),
                      const SizedBox(width: 4),
                      Text(u.online ? u.room : 'offline', style: const TextStyle(fontSize: 11.5, color: _C.inkSoft)),
                      if (u.online && u.session != '—') ...[
                        const SizedBox(width: 10),
                        Icon(Icons.access_time_rounded, size: 13, color: _C.inkSoft),
                        const SizedBox(width: 4),
                        Text(u.session, style: const TextStyle(fontSize: 11.5, color: _C.inkSoft)),
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
                  child: Icon(Icons.more_horiz_rounded, color: _C.brownDarker, size: 20),
                ),
              ),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: _C.border.withValues(alpha: .6)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _ActionBtn(label: 'Profile', icon: Icons.person_outline_rounded, tone: 'neutral', onTap: () => widget.onAction('view'))),
              const SizedBox(width: 6),
              Expanded(child: _ActionBtn(label: 'Kick', icon: Icons.logout_rounded, tone: 'warn', disabled: !u.online, onTap: () => widget.onAction('kick'))),
              const SizedBox(width: 6),
              Expanded(child: _ActionBtn(label: 'Ban', icon: Icons.block_rounded, tone: 'danger', onTap: () => widget.onAction('ban'))),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─── Action button ───
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final String tone;
  final bool disabled;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.tone, required this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'neutral': (bg: const Color(0xFFF6EAD0), fg: _C.brownDarker),
      'warn':    (bg: const Color(0xFFFAE7C8), fg: const Color(0xFF8A5A14)),
      'danger':  (bg: _C.redSoft,              fg: const Color(0xFF9F2A18)),
    }[tone]!;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? .4 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: colors.fg),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.fg)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Banned Card ───
class _BannedCard extends StatelessWidget {
  final BannedUser banned;
  final VoidCallback onUnban;
  const _BannedCard({required this.banned, required this.onUnban});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0,4))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: _C.redSoft, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.block_rounded, color: Color(0xFF9F2A18), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(banned.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _C.ink)),
                    const SizedBox(height: 2),
                    Text(banned.reason, style: const TextStyle(fontSize: 11.5, color: _C.inkSoft)),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: _C.brownDarker, borderRadius: BorderRadius.circular(999)),
                  child: Text(banned.duration, style: const TextStyle(color: Color(0xFFFFF7E8), fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 4),
                Text(banned.date, style: const TextStyle(fontSize: 10.5, color: _C.inkSoft)),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text.rich(TextSpan(
                  children: [
                    TextSpan(text: 'by ', style: TextStyle(fontSize: 11, color: _C.inkSoft)),
                    TextSpan(text: banned.by, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.ink)),
                  ],
                )),
              ),
              GestureDetector(
                onTap: onUnban,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(999)),
                  child: Text('Unban', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _C.greenInk)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Ban Modal (2-step) ───
class _BanModal extends StatefulWidget {
  final String username;
  final VoidCallback onClose;
  final void Function(String name, String reason, String duration) onConfirm;
  const _BanModal({required this.username, required this.onClose, required this.onConfirm});

  @override
  State<_BanModal> createState() => _BanModalState();
}

class _BanModalState extends State<_BanModal> {
  int _step = 1;
  String? _reason;
  String _other = '';
  String _duration = 'Permanent';
  final _otherCtrl = TextEditingController();

  @override
  void dispose() { _otherCtrl.dispose(); super.dispose(); }

  String get _finalReason => (_reason == 'Others' && _other.isNotEmpty) ? 'Others: $_other' : (_reason ?? '');
  bool get _canNext => _reason != null && !(_reason == 'Others' && _other.isEmpty);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: .5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .2), blurRadius: 40, offset: const Offset(0,22))]),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(children: [
                  Container(width: 32, height: 32, decoration: BoxDecoration(color: _C.redSoft, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.block_rounded, color: Color(0xFF9F2A18), size: 18)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Ban ${widget.username}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _C.ink))),
                  GestureDetector(onTap: widget.onClose,
                    child: Icon(Icons.close_rounded, color: _C.inkSoft, size: 22)),
                ]),
                const SizedBox(height: 14),
                // Step indicators
                Row(children: [
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(
                    color: _step >= 1 ? _C.red : _C.border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 6),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(
                    color: _step >= 2 ? _C.red : _C.border, borderRadius: BorderRadius.circular(2)))),
                ]),
                const SizedBox(height: 14),
                if (_step == 1) ..._buildStep1(),
                if (_step == 2) ..._buildStep2(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep1() => [
    Text('Why are you banning this user? Choose one.', style: TextStyle(fontSize: 13, color: _C.inkSoft)),
    const SizedBox(height: 12),
    ..._banReasons.map((r) {
      final active = _reason == r;
      return GestureDetector(
        onTap: () => setState(() => _reason = r),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? _C.green : Colors.white,
            border: Border.all(color: active ? _C.greenInk.withValues(alpha: .4) : _C.border, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: active ? _C.greenInk : Colors.white,
                border: Border.all(color: active ? _C.greenInk : _C.border, width: 1.5),
                borderRadius: BorderRadius.circular(5),
              ),
              child: active ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(r, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: _C.ink))),
          ]),
        ),
      );
    }),
    if (_reason == 'Others')
      TextField(
        controller: _otherCtrl,
        onChanged: (v) => setState(() => _other = v),
        maxLines: 2,
        decoration: InputDecoration(
          hintText: 'Type the reason…',
          hintStyle: TextStyle(color: _C.inkSoft, fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _C.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _C.border, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.brownDarker, width: 1.5)),
          contentPadding: const EdgeInsets.all(10),
        ),
        style: const TextStyle(fontSize: 13, color: _C.ink),
      ),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: _ModalBtn(label: 'Cancel', bg: _C.neutral, fg: _C.ink, onTap: widget.onClose)),
      const SizedBox(width: 10),
      Expanded(child: _ModalBtn(label: 'Next', bg: _C.green, fg: _C.greenInk, onTap: _canNext ? () => setState(() => _step = 2) : null)),
    ]),
  ];

  List<Widget> _buildStep2() => [
    Text('How long should the ban last?', style: TextStyle(fontSize: 13, color: _C.inkSoft)),
    const SizedBox(height: 12),
    GridView.count(
      crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.5,
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      children: ['1 day', '7 days', '30 days', 'Permanent'].map((d) {
        final active = _duration == d;
        return GestureDetector(
          onTap: () => setState(() => _duration = d),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? _C.brownDarker : Colors.white,
              border: Border.all(color: active ? _C.brownDarker : _C.border, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(d, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: active ? const Color(0xFFFFF6E2) : _C.ink)),
          ),
        );
      }).toList(),
    ),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF6EAD0), borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.warning_amber_rounded, color: const Color(0xFF8A5A14), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text.rich(TextSpan(
          style: const TextStyle(fontSize: 12.5, color: _C.ink, height: 1.5),
          children: [
            TextSpan(text: widget.username, style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' will be banned for '),
            TextSpan(text: _duration.toLowerCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' for '),
            TextSpan(text: _finalReason, style: const TextStyle(fontWeight: FontWeight.w800)),
            const TextSpan(text: '. They will be removed from their current room immediately.'),
          ],
        ))),
      ]),
    ),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: _ModalBtn(label: 'Back', bg: _C.neutral, fg: _C.ink, onTap: () => setState(() => _step = 1))),
      const SizedBox(width: 10),
      Expanded(child: _ModalBtn(
        label: 'Confirm Ban', bg: _C.red, fg: Colors.white,
        icon: Icons.block_rounded,
        onTap: () => widget.onConfirm(widget.username, _finalReason, _duration),
      )),
    ]),
  ];
}

class _ModalBtn extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final VoidCallback? onTap;
  final IconData? icon;
  const _ModalBtn({required this.label, required this.bg, required this.fg, this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}

// ─── Toast ───
class _Toast extends StatelessWidget {
  final String msg;
  const _Toast({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .2), blurRadius: 16, offset: const Offset(0,4))]),
        child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: _C.greenInk, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }
}
