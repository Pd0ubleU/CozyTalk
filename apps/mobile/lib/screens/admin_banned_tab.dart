import 'package:flutter/material.dart';
import 'admin_shared.dart';

// ─── Banned Card ───
class AdminBannedCard extends StatelessWidget {
  final BannedUser banned;
  final VoidCallback onTap;
  const AdminBannedCard({super.key, required this.banned, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                Stack(
                  children: [
                    AdminMascotAvatar(size: 48),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AdminC.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.block_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banned.name,
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AdminC.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        banned.reason,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          fontSize: 11.5,
                          color: AdminC.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AdminC.brownDarker,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        banned.duration,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: const Color(0xFFFFF7E8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      banned.date,
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        fontSize: 10.5,
                        color: AdminC.inkSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AdminC.border.withValues(alpha: .5)),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
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
                      text: banned.by,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminC.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Banned Tab ───
class AdminBannedTab extends StatelessWidget {
  final List<BannedUser> banned;
  final String query;
  final void Function(BannedUser) onOpen;
  const AdminBannedTab({
    super.key,
    required this.banned,
    required this.query,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final list = banned
        .where(
          (b) =>
              b.name.toLowerCase().contains(q) ||
              b.uid.toLowerCase().contains(q),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${banned.length}',
                  style: const TextStyle(
                    color: AdminC.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const TextSpan(
                  text: ' active bans',
                  style: TextStyle(
                    color: AdminC.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        ...list.map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AdminBannedCard(banned: b, onTap: () => onOpen(b)),
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'No bans match "$query".',
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
