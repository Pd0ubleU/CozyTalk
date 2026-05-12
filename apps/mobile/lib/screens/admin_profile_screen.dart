import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Design tokens
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
  // border unused but kept for reference
}

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});
  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  bool _showLogoutConfirm = false;

  // Mock admin data
  final _adminName     = 'Modkun';
  final _adminEmail    = 'admin@cozytalk.app';
  final _adminRole     = 'Senior Moderator';
  final _adminResolved = 142;
  final _adminBans     = 38;
  final _adminDuty     = '4h 12m';
  final _adminBanCount = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.cream,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  children: [
                    _buildProfileCard(),
                    const SizedBox(height: 12),
                    _buildEmailCard(),
                    const SizedBox(height: 12),
                    _buildStatsRow(),
                    const SizedBox(height: 12),
                    _buildRowCard(
                      icon: Icons.block_rounded,
                      iconColor: _C.brownDarker,
                      label: 'Banned users',
                      trailing: Text('$_adminBanCount', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.inkSoft)),
                    ),
                    const SizedBox(height: 12),
                    _buildDiscordRow(),
                    const SizedBox(height: 24),
                    _buildLogoutButton(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
          if (_showLogoutConfirm) _buildLogoutConfirmOverlay(context),
        ],
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _C.brown,
      padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 22, 18, 28),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 4, offset: const Offset(0,2))],
              ),
              child: const Icon(Icons.chevron_left_rounded, color: _C.brownDarker, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          const Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }

  // ─── Profile card ───
  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0,4))],
      ),
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          Row(
            children: [
              Container(
                width: 92, height: 92,
                decoration: BoxDecoration(
                  color: _C.creamDeep,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 4, offset: const Offset(0,2))],
                ),
                child: const Icon(Icons.person, color: _C.brownDarker, size: 52),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Username', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.inkSoft)),
                    const SizedBox(height: 2),
                    Text(_adminName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.ink)),
                    const SizedBox(height: 8),
                    const Text('Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.inkSoft)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.shield_rounded, size: 13, color: _C.greenInk),
                        const SizedBox(width: 4),
                        Text(_adminRole, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _C.greenInk)),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Edit button
          Positioned(
            top: 0, right: 0,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: _C.creamDeep, borderRadius: BorderRadius.circular(9)),
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/Edit.svg',
                  width: 16, height: 16,
                  colorFilter: const ColorFilter.mode(_C.brownDarker, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Email row ───
  Widget _buildEmailCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0,4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.email_outlined, color: _C.brownDarker, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.inkSoft)),
              const SizedBox(height: 2),
              Text(_adminEmail, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Stats row ───
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _StatBox(label: 'Resolved',   value: '$_adminResolved', valueColor: _C.greenInk)),
        const SizedBox(width: 8),
        Expanded(child: _StatBox(label: 'Bans issued', value: '$_adminBans',   valueColor: const Color(0xFF9F2A18))),
        const SizedBox(width: 8),
        Expanded(child: _StatBox(label: 'On duty',    value: _adminDuty,        valueColor: _C.brownDarker)),
      ],
    );
  }

  // ─── Generic row card ───
  Widget _buildRowCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0,4))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _C.ink))),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // ─── Discord row ───
  Widget _buildDiscordRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0,4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: const Color(0xFF5865F2), borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: SvgPicture.asset(
                'assets/images/Discord.svg',
                width: 16, height: 16,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Contact us', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _C.ink))),
          const Text('@CozyTalk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.inkSoft)),
        ],
      ),
    );
  }

  // ─── Logout button ───
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => setState(() => _showLogoutConfirm = true),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0,4))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/images/LogOut.svg',
              width: 20, height: 20,
              colorFilter: const ColorFilter.mode(Color(0xFF9F2A18), BlendMode.srcIn),
            ),
            const SizedBox(width: 14),
            const Text('Log out', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _C.ink)),
          ],
        ),
      ),
    );
  }

  // ─── Logout confirm overlay ───
  Widget _buildLogoutConfirmOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: .5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .2), blurRadius: 40, offset: const Offset(0,22))],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: _C.redSoft, borderRadius: BorderRadius.circular(14)),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/images/LogOut.svg',
                      width: 26, height: 26,
                      colorFilter: const ColorFilter.mode(Color(0xFF9F2A18), BlendMode.srcIn),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Log out of CozyTalk?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _C.ink)),
                const SizedBox(height: 6),
                const Text("You'll need to sign back in to keep moderating.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _C.inkSoft, height: 1.5)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showLogoutConfirm = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(color: _C.neutral, borderRadius: BorderRadius.circular(999)),
                          child: const Center(child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _C.ink))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _showLogoutConfirm = false);
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(color: _C.red, borderRadius: BorderRadius.circular(999)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/images/LogOut.svg',
                                width: 16, height: 16,
                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                              ),
                              const SizedBox(width: 6),
                              const Text('Log out', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Stat box ───
class _StatBox extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _StatBox({required this.label, required this.value, required this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0,4))],
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: valueColor)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _C.inkSoft), textAlign: TextAlign.center),
      ]),
    );
  }
}
