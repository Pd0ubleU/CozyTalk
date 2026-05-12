import 'package:flutter/material.dart';
import 'admin_shared.dart';

// ─── Banned Card ───
class AdminBannedCard extends StatelessWidget {
  final BannedUser banned;
  final VoidCallback onUnban;
  const AdminBannedCard({super.key, required this.banned, required this.onUnban});

  @override
  Widget build(BuildContext context) {
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
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: AdminC.redSoft, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.block_rounded, color: Color(0xFF9F2A18), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(banned.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AdminC.ink)),
                    const SizedBox(height: 2),
                    Text(banned.reason, style: const TextStyle(fontSize: 11.5, color: AdminC.inkSoft)),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: AdminC.brownDarker, borderRadius: BorderRadius.circular(999)),
                  child: Text(banned.duration, style: const TextStyle(color: Color(0xFFFFF7E8), fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 4),
                Text(banned.date, style: const TextStyle(fontSize: 10.5, color: AdminC.inkSoft)),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text.rich(TextSpan(
                  children: [
                    const TextSpan(text: 'by ', style: TextStyle(fontSize: 11, color: AdminC.inkSoft)),
                    TextSpan(text: banned.by, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminC.ink)),
                  ],
                )),
              ),
              GestureDetector(
                onTap: onUnban,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: AdminC.green, borderRadius: BorderRadius.circular(999)),
                  child: Text('Unban', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdminC.greenInk)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Banned Tab ───
class AdminBannedTab extends StatelessWidget {
  final List<BannedUser> banned;
  final String query;
  final void Function(BannedUser) onUnban;
  const AdminBannedTab({
    super.key,
    required this.banned,
    required this.query,
    required this.onUnban,
  });

  @override
  Widget build(BuildContext context) {
    final list = banned.where((b) => b.name.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RichText(text: TextSpan(children: [
            TextSpan(text: '${banned.length}', style: const TextStyle(color: AdminC.ink, fontWeight: FontWeight.w800, fontSize: 13)),
            const TextSpan(text: ' active bans', style: TextStyle(color: AdminC.inkSoft, fontWeight: FontWeight.w600, fontSize: 13)),
          ])),
        ),
        ...list.map((b) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AdminBannedCard(
            banned: b,
            onUnban: () => onUnban(b),
          ),
        )),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text('No bans match "$query".', style: const TextStyle(color: AdminC.inkSoft, fontSize: 13))),
          ),
      ],
    );
  }
}
