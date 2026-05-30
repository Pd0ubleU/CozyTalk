import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';

// Design tokens
class _C {
  static const brown = Color(0xFF6E5B57);
  static const brownDarker = Color(0xFF3F3230);
  static const cream = Color(0xFFFBF4E5);
  static const greenInk = Color(0xFF3F4E1F);
  static const red = Color(0xFFD85542);
  static const redSoft = Color(0xFFF1DDD7);
  static const neutral = Color(0xFFD8D2C8);
  static const ink = Color(0xFF1F1A18);
  static const inkSoft = Color(0xFF6B5F5A);
  // border unused but kept for reference
}

class AdminProfileScreen extends ConsumerStatefulWidget {
  final int resolvedCount;
  final int bansCount;
  const AdminProfileScreen({
    super.key,
    this.resolvedCount = 0,
    this.bansCount = 0,
  });
  @override
  ConsumerState<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends ConsumerState<AdminProfileScreen> {
  bool _showLogoutConfirm = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final adminEmail = authState.user?.email ?? '';
    final adminName = adminEmail.contains('@')
        ? adminEmail.split('@').first
        : (authState.user?.displayName ?? 'Admin');
    return Scaffold(
      backgroundColor: _C.cream,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: Column(
                          children: [
                            _buildProfileCard(adminName),
                            const SizedBox(height: 12),
                            _buildEmailCard(adminEmail),
                            const SizedBox(height: 12),
                            _buildStatsRow(),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        MediaQuery.of(context).padding.bottom + 20,
                      ),
                      child: _buildLogoutButton(),
                    ),
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
                color: _C.brownDarker,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Profile card ───
  Widget _buildProfileCard(String adminName) {
    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.person, color: _C.brownDarker, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Username',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _C.inkSoft,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                adminName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _C.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Email row ───
  Widget _buildEmailCard(String adminEmail) {
    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.email_outlined, color: _C.brownDarker, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Email',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _C.inkSoft,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                adminEmail,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _C.ink,
                ),
              ),
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
        Expanded(
          child: _StatBox(
            label: 'Resolved',
            value: '${widget.resolvedCount}',
            valueColor: _C.greenInk,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBox(
            label: 'Bans issued',
            value: '${widget.bansCount}',
            valueColor: const Color(0xFF9F2A18),
          ),
        ),
      ],
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.logout_rounded, size: 20, color: _C.ink),
            const SizedBox(width: 14),
            const Text(
              'Log out',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: _C.ink,
              ),
            ),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .2),
                  blurRadius: 40,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _C.redSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: const Icon(
                      Icons.logout_rounded,
                      size: 26,
                      color: Color(0xFF9F2A18),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Log out of CozyTalk?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: _C.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "You'll need to sign back in to keep moderating.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _C.inkSoft,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showLogoutConfirm = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: _C.neutral,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: _C.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          setState(() => _showLogoutConfirm = false);
                          final navigator = Navigator.of(context);
                          await ref
                              .read(authNotifierProvider.notifier)
                              .signOut();
                          if (!mounted) return;
                          navigator.popUntil((route) => route.isFirst);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: _C.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.logout_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Log out',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
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
  const _StatBox({
    required this.label,
    required this.value,
    required this.valueColor,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: _C.inkSoft,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
