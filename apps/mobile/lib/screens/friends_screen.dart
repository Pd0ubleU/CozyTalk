import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import '../features/friends/domain/entities/friend.dart' as domain;
import '../features/friends/domain/entities/friend_room_status.dart';
import '../features/friends/presentation/providers/friends_provider.dart';
import '../shared/connectivity_provider.dart';
import '../shared/info_dialog.dart';
import '../shared/offline_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';
import '../models/friend.dart';
import 'friend_profile_dialog.dart';
import 'remove_friend_dialog.dart';
import 'block_dialogs.dart';
import 'widgets.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  // Local-only state — no backend support yet
  final Map<String, String?> _notes = {};
  final Set<String> _blockedIds = {};
  final Map<String, int> _unreadCounts = {};
  String? _pendingRemoveName;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Friend _toScreenFriend(domain.Friend f, FriendsState state) {
    final roomStatus = state.roomMap[f.friendUid];
    return Friend(
      friendshipId: f.friendshipId,
      chatRoomId: f.chatRoomId,
      name: f.friendDisplayName,
      username: f.friendDisplayName,
      note: _notes[f.friendshipId],
      lastMessage: state.lastMessageMap[f.chatRoomId] ?? '',
      isOnline: state.presenceMap[f.friendUid] ?? false,
      unreadCount: _unreadCounts[f.friendshipId] ?? 0,
      isBlocked: _blockedIds.contains(f.friendshipId),
      room: roomStatus != null ? _toRoomInfo(roomStatus) : null,
    );
  }

  RoomInfo _toRoomInfo(FriendRoomStatus s) => RoomInfo(
    name: s.mode == '1v1' ? '1v1 Room' : 'Group Room',
    thumbnail: s.mode == '1v1'
        ? 'assets/images/1on1_doodle.png'
        : 'assets/images/group_doodle.png',
    current: s.memberCount,
    max: s.maxUsers,
    isLocked: s.isLocked,
  );

  List<Friend> _filtered(List<Friend> friends) => _query.isEmpty
      ? friends
      : friends
            .where(
              (f) =>
                  f.displayName.toLowerCase().contains(_query) ||
                  f.username.toLowerCase().contains(_query),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsNotifierProvider);
    final friends = state.friends
        .map((f) => _toScreenFriend(f, state))
        .toList();
    final filtered = _filtered(friends);
    final isOffline = !ref
        .watch(isOnlineProvider)
        .when(data: (v) => v, loading: () => true, error: (_, _) => true);

    ref.listen<FriendsState>(friendsNotifierProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
        ref.read(friendsNotifierProvider.notifier).clearError();
      }
      if (prev?.isLoading == true && !next.isLoading && next.error == null) {
        final name = _pendingRemoveName;
        if (name != null) {
          _pendingRemoveName = null;
          showInfoDialog(
            context,
            type: InfoDialogType.info,
            title: 'Friend Removed',
            message: '$name has been removed from your friends list.',
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          if (isOffline)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: OfflineCard(),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: filtered.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildSearchBar();
                  final friend = filtered[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildFriendCard(friend),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/images/icons/Search.svg',
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search your friends...',
                hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: const Color(0xFF757575),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(Friend friend) {
    final showRoom = friend.room != null && friend.isOnline;
    return GestureDetector(
      onTap: () {
        if (friend.unreadCount > 0) {
          setState(() => _unreadCounts[friend.friendshipId] = 0);
        }
        Navigator.pushNamed(context, AppRoutes.friendChat, arguments: friend);
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, showRoom ? 8 : 16),
              child: Row(
                children: [
                  // ── Avatar + online dot ──
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: const Center(
                            child: Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 35,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: friend.isOnline
                                ? const Color(0xFF86BA73)
                                : Colors.grey.shade300,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: friend.isOnline
                                  ? const Color(0xFF72A161)
                                  : Colors.grey.shade400,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // ── Name + last message ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.displayName,
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          friend.lastMessage,
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                fontSize: 14,
                                color: friend.unreadCount > 0
                                    ? Colors.black
                                    : Colors.grey.shade600,
                                fontWeight: friend.unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // ── Actions ──
                  SizedBox(
                    height: 75,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildMoreButton(friend),
                        if (friend.unreadCount > 0)
                          _buildUnreadBadge(friend.unreadCount)
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showRoom) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: FriendRoomCard(
                  room: friend.room!,
                  onJoin: friend.room!.canJoin
                      ? () => Navigator.pushNamed(
                          context,
                          AppRoutes.groupChatScreen,
                          arguments: {
                            'roomName': friend.room!.name,
                            'bgImage': friend.room!.thumbnail,
                          },
                        )
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.redOrange,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFA33615), width: 1.5),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMoreButton(Friend friend) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: SvgPicture.asset(
        'assets/images/icons/ThreeDot.svg',
        width: 36,
        height: 36,
      ),
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      offset: const Offset(0, 36),
      onSelected: (value) {
        switch (value) {
          case 'Edit':
            showFriendProfileDialog(
              context: context,
              friend: friend,
              onNoteSaved: (newNote) {
                setState(() {
                  _notes[friend.friendshipId] = newNote.isNotEmpty
                      ? newNote
                      : null;
                });
              },
            );
          case 'Block':
            showConfirmBlockDialog(
              context: context,
              username: friend.displayName,
              onConfirm: () {
                setState(() => _blockedIds.add(friend.friendshipId));
                showInfoDialog(
                  context,
                  type: InfoDialogType.success,
                  title: 'User Blocked',
                  message:
                      '${friend.displayName} has been blocked locally.\nServer-side enforcement is not yet available.',
                );
              },
            );
          case 'Unblock':
            showConfirmUnblockDialog(
              context: context,
              username: friend.displayName,
              onConfirm: () {
                setState(() => _blockedIds.remove(friend.friendshipId));
                showInfoDialog(
                  context,
                  type: InfoDialogType.info,
                  title: 'User Unblocked',
                  message:
                      '${friend.displayName} has been unblocked.\nThey can now contact you again.',
                );
              },
            );
          case 'Unfriend':
            showRemoveConfirmDialog(
              context: context,
              friend: friend,
              onConfirm: () {
                if (ref.read(friendsNotifierProvider).isLoading) return;
                _pendingRemoveName = friend.displayName;
                ref
                    .read(friendsNotifierProvider.notifier)
                    .removeFriend(friend.friendshipId);
              },
            );
        }
      },
      itemBuilder: (_) => [
        _popupItem('Edit'),
        _divider(),
        _popupItem(friend.isBlocked ? 'Unblock' : 'Block'),
        _divider(),
        _popupItem('Unfriend'),
      ],
    );
  }

  PopupMenuEntry<String> _divider() {
    return PopupMenuItem<String>(
      enabled: false,
      height: 1,
      padding: EdgeInsets.zero,
      child: Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
    );
  }

  PopupMenuItem<String> _popupItem(String label) {
    return PopupMenuItem<String>(
      value: label,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 110,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brownDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 90,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
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
                const Text(
                  'Friends',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
