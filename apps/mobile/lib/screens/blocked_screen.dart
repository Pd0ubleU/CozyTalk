import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/block/presentation/providers/block_provider.dart';
import '../theme/app_colors.dart';
import '../models/friend.dart';
import '../shared/layered_avatar.dart';
import 'friend_profile_dialog.dart';
import 'block_dialogs.dart';

class BlockedScreen extends ConsumerStatefulWidget {
  const BlockedScreen({super.key});

  @override
  ConsumerState<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends ConsumerState<BlockedScreen> {
  static const int _maxBlocked = 5;
  final Map<String, String?> _notes = {};

  @override
  Widget build(BuildContext context) {
    final blockState = ref.watch(blockNotifierProvider);
    final blocked = blockState.blockedUsers;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildCustomAppBar(context),
          Padding(
            padding: const EdgeInsets.only(top: 20, right: 30, bottom: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${blocked.length}/$_maxBlocked',
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF757575),
                ),
              ),
            ),
          ),
          Expanded(
            child: blocked.isEmpty
                ? Center(
                    child: Text(
                      'No blocked users',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: const Color(0xFF757575),
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: blocked.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, i) {
                      final user = blocked[i];
                      final note = _notes[user.uid];
                      final friend = Friend(
                        name: user.displayName ?? user.uid,
                        username: user.uid,
                        note: note,
                        lastMessage: '',
                        isOnline: false,
                        interest: '',
                      );
                      return _buildBlockedCard(context, friend, user.uid);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Custom App Bar ───
  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brownDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: 'Go back',
                button: true,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: SvgPicture.asset(
                      'assets/images/icons/Back.svg',
                      width: 26,
                      height: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Blocked',
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Blocked User Card ───
  Widget _buildBlockedCard(
    BuildContext context,
    Friend friend,
    String targetUid,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Row(
        children: [
          // ── Avatar (tappable → profile dialog) ──
          Semantics(
            label: 'View user profile',
            button: true,
            child: GestureDetector(
              onTap: () => showFriendProfileDialog(
                context: context,
                friend: friend,
                onNoteSaved: (note) => setState(
                  () => _notes[targetUid] = note.isNotEmpty ? note : null,
                ),
              ),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(child: LayeredAvatar(boxSize: 44)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // ── Display name ──
          Expanded(
            child: Text(
              friend.displayName,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ),
          // ── Unblock button ──
          GestureDetector(
            onTap: () => showConfirmUnblockDialog(
              context: context,
              username: friend.displayName,
              onConfirm: () =>
                  ref.read(blockNotifierProvider.notifier).unblock(targetUid),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDEDEDE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade400, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Unblock',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
