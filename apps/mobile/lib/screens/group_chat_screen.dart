import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/chat/domain/entities/chat_message.dart' as chat_entity;
import '../features/chat/domain/entities/session_status.dart';
import '../features/chat/presentation/providers/chat_provider.dart';
import '../features/matchmaking/presentation/providers/matchmaking_provider.dart';
import '../theme/app_colors.dart';
import '../dialogs/leave_room_dialog.dart';
import '../dialogs/song_dialog.dart';
import '../dialogs/user_profile_dialog.dart';
import '../dialogs/members_list_dialog.dart';
import '../shared/avatar_overlay.dart';
import '../shared/layered_avatar.dart';
import '../shared/press_bounce_btn.dart';
import '../shared/user_profile.dart';
import '../shared/friend_message_popup.dart';
import '../theme/app_routes.dart';
import '../models/friend.dart';
import '../shared/gif_picker.dart';
import '../shared/friend_request_popup.dart';
import '../shared/info_dialog.dart';

// ── Card assets ────────────────────────────────────────────────────────────
const _cardAssets = [
  'assets/images/cards/card1.png',
  'assets/images/cards/card2.png',
  'assets/images/cards/card3.png',
  'assets/images/cards/card4.png',
  'assets/images/cards/card5.png',
  'assets/images/cards/card6.png',
];

String _pickCard() => _cardAssets[Random().nextInt(_cardAssets.length)];

// ── Message model ──────────────────────────────────────────────────────────
enum _MsgType { warning, system, me, other, card, gif, gifOther }

class _GroupMsg {
  final _MsgType type;
  final String text; // for card = asset path
  final String? sender;
  final String? time;
  const _GroupMsg({
    required this.type,
    required this.text,
    this.sender,
    this.time,
  });
}

// ── Avatar layout presets (leftFrac, bottomPx, sizePx) per member count ────
// leftFrac: fraction of total banner width (0.0–1.0); side buttons occupy ~0.20 on right
typedef _AvatarPos = ({double x, double bottom, double size});

const List<List<_AvatarPos>> _layouts = [
  [], // 0 members — unused
  [
    // 1 member — center
    (x: 0.36, bottom: 14, size: 88),
  ],
  [
    // 2 members
    (x: 0.10, bottom: 12, size: 80),
    (x: 0.55, bottom: 12, size: 80),
  ],
  [
    // 3 members — staggered (matches design)
    (x: 0.04, bottom: 8, size: 75),
    (x: 0.34, bottom: 32, size: 75),
    (x: 0.60, bottom: 8, size: 75),
  ],
  [
    // 4 members
    (x: 0.02, bottom: 8, size: 65),
    (x: 0.23, bottom: 28, size: 65),
    (x: 0.44, bottom: 28, size: 65),
    (x: 0.64, bottom: 8, size: 65),
  ],
  [
    // 5 members
    (x: 0.01, bottom: 8, size: 55),
    (x: 0.17, bottom: 26, size: 55),
    (x: 0.33, bottom: 8, size: 55),
    (x: 0.50, bottom: 26, size: 55),
    (x: 0.66, bottom: 8, size: 55),
  ],
];

// ── Screen ─────────────────────────────────────────────────────────────────
class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen>
    with TickerProviderStateMixin {
  final Map<String, bool> _friendRequestSent = {};
  final Map<String, bool> _friendAccepted = {};
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Timer? _typingTimer;
  Timer? _friendMsgTimer;

  // ── Members panel animation ──
  bool _panelOpen = false;
  late final AnimationController _panelCtrl;
  late final Animation<Offset> _panelSlide;

  // ── Song panel animation ──
  bool _songPanelOpen = false;
  late final AnimationController _songCtrl;
  late final Animation<Offset> _songSlide;

  final List<({_GroupMsg msg, int seq})> _localMessages = [];
  final List<_GroupMsg> _optimisticMessages = [];
  String? _pendingGifUrl;

  @override
  void initState() {
    super.initState();
    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));

    _songCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _songSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _songCtrl, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      final matchState = ref.read(matchmakingNotifierProvider);
      final authUser = ref.read(authNotifierProvider).user;
      final roomId = matchState.roomId;
      if (authUser == null || roomId == null) return;
      ref
          .read(chatNotifierProvider.notifier)
          .enterSession(
            sessionId: roomId,
            currentUserId: authUser.uid,
            currentUserDisplayName: authUser.displayName,
          );
    });
    _friendMsgTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      showFriendMessagePopup(
        context,
        friendName: 'Nong Prae',
        message: 'Hey! Are you free tonight? 🍕',
        onTap: () => _showLeaveForFriendChat(),
      );
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _friendMsgTimer?.cancel();
    _panelCtrl.dispose();
    _songCtrl.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openPanel() {
    if (_songPanelOpen) _closeSongPanel();
    setState(() => _panelOpen = true);
    _panelCtrl.forward();
  }

  void _closePanel() {
    _panelCtrl.reverse().then((_) {
      if (mounted) setState(() => _panelOpen = false);
    });
  }

  void _openSongPanel() {
    if (_panelOpen) _closePanel();
    setState(() => _songPanelOpen = true);
    _songCtrl.forward();
  }

  void _closeSongPanel() {
    _songCtrl.reverse().then((_) {
      if (mounted) setState(() => _songPanelOpen = false);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    });
    // Correct position after images/layout settle — jumpTo avoids conflicting with animateTo
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (_scrollController.offset < max - 5) {
        _scrollController.jumpTo(max);
      }
    });
  }

  Future<void> _sendMessage() async {
    if (ref.read(chatNotifierProvider).isSending) return;
    final notifier = ref.read(chatNotifierProvider.notifier);
    bool sent = false;
    if (_pendingGifUrl != null) {
      final url = _pendingGifUrl!;
      setState(() {
        _pendingGifUrl = null;
        _optimisticMessages.add(_GroupMsg(type: _MsgType.gif, text: url));
      });
      await notifier.sendMessage(url);
      sent = true;
    }
    final text = _msgController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _optimisticMessages.add(_GroupMsg(type: _MsgType.me, text: text));
      });
      notifier.sendMessage(text);
      notifier.setTyping(false);
      _typingTimer?.cancel();
      _msgController.clear();
      _focusNode.requestFocus();
      sent = true;
    }
    if (sent) _scrollToBottom();
  }

  void _sendTopicCard() {
    final seq = ref.read(chatNotifierProvider).messages.length;
    setState(() {
      _localMessages.add((
        msg: _GroupMsg(type: _MsgType.card, text: _pickCard()),
        seq: seq,
      ));
    });
    _scrollToBottom();
  }

  void _sendGif(String url) {
    setState(() => _pendingGifUrl = url);
  }

  void _sendFriendRequest(String targetName) {
    if (_friendRequestSent[targetName] == true) return;
    setState(() => _friendRequestSent[targetName] = true);
    showInfoDialog(
      context,
      type: InfoDialogType.info,
      title: 'Friend Request Sent',
      message:
          'Your friend request has been sent to $targetName.\nWaiting for them to accept.',
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      showFriendRequestPopup(
        context,
        requesterName: targetName,
        onAccept: () {
          setState(() => _friendAccepted[targetName] = true);
          showInfoDialog(
            context,
            type: InfoDialogType.success,
            title: "You're now friends! 🎉",
            message:
                'You and $targetName are now friends.\nYou can find them in your friends list.',
          );
        },
        onDecline: () => setState(() => _friendRequestSent[targetName] = false),
      );
    });
  }

  void _cancelFriendRequest(String targetName) {
    if (_friendAccepted[targetName] == true) {
      showInfoDialog(
        context,
        type: InfoDialogType.warning,
        title: 'Cannot Cancel Request',
        message:
            '$targetName has already accepted your friend request.\nYou are now friends!',
      );
      return;
    }
    setState(() => _friendRequestSent[targetName] = false);
    showInfoDialog(
      context,
      type: InfoDialogType.info,
      title: 'Request Cancelled',
      message: 'Your friend request to $targetName has been cancelled.',
    );
  }

  void _shuffleTopic() {
    final seq = ref.read(chatNotifierProvider).messages.length;
    setState(() {
      _localMessages.add((
        msg: const _GroupMsg(
          type: _MsgType.system,
          text: 'Someone shuffled the topic!',
        ),
        seq: seq,
      ));
      _localMessages.add((
        msg: _GroupMsg(type: _MsgType.card, text: _pickCard()),
        seq: seq,
      ));
    });
    _scrollToBottom();
  }

  void _showLeaveForFriendChat() {
    if (!mounted) return;
    final mockFriend = Friend(
      name: 'Nong Prae',
      username: 'kaitom',
      lastMessage: 'Hey! Are you free tonight? 🍕',
      isOnline: true,
      avatar: 'assets/images/UserAvatar.png',
      interest: 'Cats',
    );
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Leave this room?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You will leave this room and won\'t\nbe able to come back.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  color: Colors.black87,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD9D5D1),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(color: Color(0xFFC8C3BE)),
                          ),
                        ),
                        child: const Text(
                          'Stay',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          Navigator.popUntil(context, (route) => route.isFirst);
                          Navigator.pushNamed(context, AppRoutes.friends);
                          Navigator.pushNamed(
                            context,
                            AppRoutes.friendChat,
                            arguments: mockFriend,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD86A3B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Leave',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }

  static const _kWarning =
      'Keep it friendly! Please be respectful and protect your personal info.\n'
      'Report any suspicious behavior to help keep our community safe.';

  static String _formatTime(DateTime t) {
    final tod = TimeOfDay.fromDateTime(t);
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m ${tod.period.name}';
  }

  _GroupMsg _toGroupDisplay(chat_entity.ChatMessage msg, String? myUid) {
    final isMe = msg.senderId == myUid;
    final isGif = msg.text.contains('giphy.com');
    return _GroupMsg(
      type: isGif
          ? (isMe ? _MsgType.gif : _MsgType.gifOther)
          : (isMe ? _MsgType.me : _MsgType.other),
      text: msg.text,
      sender: isMe ? 'Me' : msg.displayName,
      time: _formatTime(msg.timestamp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final roomName = args?['roomName'] as String? ?? 'Koh Tapu';
    final roomId = args?['roomId'] as String? ?? 'ABP8C';
    final bgImage =
        args?['bgImage'] as String? ?? 'assets/images/backgrounds/kao_tapu.png';
    final maxMembers = args?['maxMembers'] as int? ?? 5;

    final avatarState = ref.watch(avatarProvider);
    final userProfile = ref.watch(userProfileProvider);
    final chatState = ref.watch(chatNotifierProvider);
    final roomType = args?['roomType'] as String?;
    final matchState = ref.watch(matchmakingNotifierProvider);
    final isLocked = matchState.currentRoom?.isLocked ?? (roomType == 'create');

    final myUid =
        chatState.currentUserId ??
        ref.watch(authNotifierProvider).user?.uid ??
        '';
    final nameMap = <String, String>{
      for (final m in chatState.messages) m.senderId: m.displayName,
    };
    final roomUsers = matchState.currentRoom?.users ?? [];
    final members = roomUsers.isEmpty
        ? ['Me']
        : roomUsers
              .map((uid) => uid == myUid ? 'Me' : (nameMap[uid] ?? 'User'))
              .toList();

    ref.listen(chatNotifierProvider.select((s) => s.status), (_, next) {
      if (next == SessionStatus.disconnected) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    ref.listen(chatNotifierProvider.select((s) => s.messages.length), (
      prev,
      next,
    ) {
      if ((prev ?? 0) < next) {
        if (_optimisticMessages.isNotEmpty) {
          setState(() => _optimisticMessages.clear());
        }
        _scrollToBottom();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          showDialog(
            context: context,
            builder: (_) => LeaveRoomDialog(
              onLeave: () {
                ref.read(matchmakingNotifierProvider.notifier).leaveRoom();
                ref.read(chatNotifierProvider.notifier).forceDisconnect();
              },
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Column(
          children: [
            // ── Header always rendered last in layout = visually on top ──
            _buildHeader(roomName, roomId, isLocked),
            // ── Content + slide-down panel clipped together ──
            Expanded(
              child: ClipRect(
                child: Stack(
                  children: [
                    // Main content
                    Column(
                      children: [
                        _buildBanner(
                          bgImage,
                          maxMembers,
                          avatarState,
                          userProfile,
                          members,
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              _buildMessageList(avatarState, chatState),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                  child: Container(
                                    height: 18,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.13),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildInputBar(),
                      ],
                    ),
                    // Barrier — tap outside to close whichever panel is open
                    if (_panelOpen || _songPanelOpen)
                      ExcludeSemantics(
                        child: GestureDetector(
                          onTap: _panelOpen ? _closePanel : _closeSongPanel,
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 260),
                            child: Container(color: Colors.black26),
                          ),
                        ),
                      ),
                    // Slide-down members panel
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SlideTransition(
                        position: _panelSlide,
                        child: MembersPanelBody(
                          members: members,
                          onClose: _closePanel,
                          avatarState: avatarState,
                          friendRequestSent: _friendRequestSent,
                          onAddFriend: _sendFriendRequest,
                          onCancelRequest: _cancelFriendRequest,
                        ),
                      ),
                    ),
                    // Slide-down song panel
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SlideTransition(
                        position: _songSlide,
                        child: SongPanelBody(onClose: _closeSongPanel),
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

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(String roomName, String roomId, bool isLocked) {
    return Container(
      width: double.infinity,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back button
                Semantics(
                  label: 'End chat',
                  button: true,
                  child: _headerBtn(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => LeaveRoomDialog(
                        onLeave: () {
                          ref
                              .read(matchmakingNotifierProvider.notifier)
                              .leaveRoom();
                          ref
                              .read(chatNotifierProvider.notifier)
                              .forceDisconnect();
                        },
                      ),
                    ),
                    child: SvgPicture.asset(
                      'assets/images/icons/Back.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Room name + ID
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomName,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Room ID:   $roomId',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Lock toggle
                Semantics(
                  label: 'Toggle room lock',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      ref
                          .read(matchmakingNotifierProvider.notifier)
                          .setRoomLock(isLocked: !isLocked);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isLocked
                            ? const Color(0xFFBA5F3A)
                            : const Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Stack(
                        children: [
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            alignment: isLocked
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isLocked
                                    ? Icons.lock_rounded
                                    : Icons.lock_open_rounded,
                                size: 16,
                                color: isLocked
                                    ? const Color(0xFFBA5F3A)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Member list button
                Semantics(
                  label: 'View member list',
                  button: true,
                  child: _headerBtn(
                    onTap: _panelOpen ? _closePanel : _openPanel,
                    child: SvgPicture.asset(
                      'assets/images/icons/memberlist.svg',
                      width: 26,
                      height: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerBtn({required Widget child, required VoidCallback onTap}) {
    return PressBounceBtn(
      onTap: onTap,
      scale: 0.90,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: child,
      ),
    );
  }

  // ── Banner with dynamic avatars ────────────────────────────────────────────
  Widget _buildBanner(
    String bgImage,
    int maxMembers,
    AvatarState avatarState,
    UserProfileState userProfile,
    List<String> members,
  ) {
    final count = members.length.clamp(1, 5);
    final preset = _layouts[count];

    final bannerHeight = count >= 5 ? 270.0 : 250.0;
    return SizedBox(
      height: bannerHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              // Background image
              Positioned.fill(
                child: Image.asset(
                  bgImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: Colors.grey.shade300),
                ),
              ),
              // Member count badge
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${members.length} / $maxMembers',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              // Avatars + thought bubbles — positioned by layout preset
              ...List.generate(count, (i) {
                final pos = preset[i];
                final username = members[i];
                final isMe = username == 'Me';
                final displayName = isMe ? userProfile.username : username;
                final thought = isMe
                    ? (userProfile.thought.isNotEmpty
                          ? userProfile.thought
                          : 'Care to share?')
                    : 'Hello!';
                final rawScale = pos.size / 90;
                final scale = rawScale.clamp(0.78, 1.0);
                final bubbleW = 84 * scale;
                final bubbleH = 94 * scale;
                return Positioned(
                  left: w * pos.x,
                  bottom: pos.bottom,
                  child: SizedBox(
                    width: pos.size,
                    height: pos.size + bubbleH * 0.75,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Semantics(
                            label: 'View user profile',
                            button: true,
                            child: GestureDetector(
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => UserProfileDialog(
                                  username: displayName,
                                  isMe: isMe,
                                  initialAdded:
                                      !isMe &&
                                      (_friendRequestSent[displayName] == true),
                                  onAddFriend: isMe
                                      ? null
                                      : () => _sendFriendRequest(displayName),
                                  onCancelRequest: isMe
                                      ? null
                                      : () => _cancelFriendRequest(displayName),
                                ),
                              ),
                              child: LayeredAvatar(
                                boxSize: pos.size,
                                moodOverlay: isMe ? avatarState.mood : null,
                                accessoryOverlay: isMe
                                    ? avatarState.accessory
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: pos.size * 0.94,
                          left: (pos.size - bubbleW) / 2,
                          child: Container(
                            width: bubbleW,
                            height: bubbleH,
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(
                                  'assets/images/chat_t_bubble.png',
                                ),
                                fit: BoxFit.contain,
                              ),
                            ),
                            padding: EdgeInsets.all(9 * scale),
                            alignment: Alignment.center,
                            child: Text(
                              thought,
                              style: TextStyle(
                                fontSize: (10 * scale).clamp(8.0, 11.0),
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              // Song / Topic buttons
              Positioned(
                bottom: 10,
                right: 10,
                child: Column(
                  children: [
                    _sideBtn(
                      'Song',
                      'assets/images/icons/song.svg',
                      _openSongPanel,
                    ),
                    const SizedBox(height: 10),
                    _sideBtn(
                      'Topic',
                      'assets/images/icons/card.svg',
                      _sendTopicCard,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sideBtn(String label, String svgPath, VoidCallback onTap) {
    return PressBounceBtn(
      onTap: onTap,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            SvgPicture.asset(svgPath, width: 26, height: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessageList(AvatarState avatarState, ChatState chatState) {
    final backendMsgs = chatState.messages
        .map((m) => _toGroupDisplay(m, chatState.currentUserId))
        .toList();
    final merged = <_GroupMsg>[
      const _GroupMsg(type: _MsgType.warning, text: _kWarning),
    ];
    int localIdx = 0;
    for (int i = 0; i <= backendMsgs.length; i++) {
      while (localIdx < _localMessages.length &&
          _localMessages[localIdx].seq <= i) {
        merged.add(_localMessages[localIdx].msg);
        localIdx++;
      }
      if (i < backendMsgs.length) merged.add(backendMsgs[i]);
    }
    final displayMessages = [...merged, ..._optimisticMessages];
    final isTyping = chatState.typingUsers.isNotEmpty;
    final itemCount = displayMessages.length + (isTyping ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        if (i == displayMessages.length && isTyping) {
          return const _GroupTypingIndicator();
        }
        final msg = displayMessages[i];
        return switch (msg.type) {
          _MsgType.warning => _buildWarning(msg.text),
          _MsgType.system => _buildSystem(msg),
          _MsgType.card => _buildCard(msg.text),
          _MsgType.gif => _buildGifBubble(msg, avatarState, isMe: true),
          _MsgType.gifOther => _buildGifBubble(msg, avatarState, isMe: false),
          _ => _buildChatBubble(msg, avatarState),
        };
      },
    );
  }

  Widget _buildWarning(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3D4BA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC87A5B)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: const Color(0xFF836151),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSystem(_GroupMsg msg) {
    return Column(
      children: [
        if (msg.time != null) ...[
          const SizedBox(height: 8),
          Text(
            msg.time!,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.60),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            msg.text,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildChatBubble(_GroupMsg msg, AvatarState avatarState) {
    final isMe = msg.type == _MsgType.me;
    final maxW = MediaQuery.of(context).size.width * 0.60;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (others only)
          if (!isMe) ...[
            Semantics(
              label: 'View user profile',
              button: true,
              child: GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => UserProfileDialog(
                    username: msg.sender ?? '',
                    initialAdded: _friendRequestSent[msg.sender ?? ''] == true,
                    onAddFriend: () => _sendFriendRequest(msg.sender ?? ''),
                    onCancelRequest: () =>
                        _cancelFriendRequest(msg.sender ?? ''),
                  ),
                ),
                child: LayeredAvatar(boxSize: 40),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Bubble + timestamp
          Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    msg.sender ?? '',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isMe) ...[
                    Text(
                      msg.time ?? '',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        fontSize: 10,
                        color: Colors.black.withValues(alpha: 0.60),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    constraints: BoxConstraints(maxWidth: maxW),
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFFF1CEE4)
                          : const Color(0xFFDCEBCE),
                      borderRadius: BorderRadius.circular(18),
                      border: isMe ? null : Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      msg.text,
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),
                  if (!isMe) ...[
                    const SizedBox(width: 6),
                    Text(
                      msg.time ?? '',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        fontSize: 10,
                        color: Colors.black.withValues(alpha: 0.60),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          // My avatar (right side)
          if (isMe) ...[
            const SizedBox(width: 8),
            LayeredAvatar(
              boxSize: 40,
              moodOverlay: avatarState.mood,
              accessoryOverlay: avatarState.accessory,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(String assetPath) {
    return _TopicCard(assetPath: assetPath, onShuffle: _shuffleTopic);
  }

  Widget _buildGifBubble(
    _GroupMsg msg,
    AvatarState avatarState, {
    required bool isMe,
  }) {
    final maxW = MediaQuery.of(context).size.width * 0.55;
    final gifImage = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        msg.text,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'GIF',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF4A3228),
            ),
          ),
        ),
      ),
    );
    final gifContainer = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFF1CEE4) : const Color(0xFFDCEBCE),
        borderRadius: BorderRadius.circular(18),
        border: isMe ? null : Border.all(color: Colors.black12),
      ),
      child: gifImage,
    );
    final timestamp = Text(
      msg.time ?? '',
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        fontSize: 10,
        color: Colors.black.withValues(alpha: 0.60),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            LayeredAvatar(boxSize: 40),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    msg.sender ?? '',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [gifContainer, const SizedBox(width: 6), timestamp],
                ),
              ],
            ),
          ] else ...[
            timestamp,
            const SizedBox(width: 6),
            gifContainer,
            const SizedBox(width: 8),
            LayeredAvatar(
              boxSize: 40,
              moodOverlay: avatarState.mood,
              accessoryOverlay: avatarState.accessory,
            ),
          ],
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      color: const Color(0xFF6B5E5B),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingGifUrl != null) _buildGifPreview(),
          _buildInputRow(),
        ],
      ),
    );
  }

  Widget _buildGifPreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _pendingGifUrl!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 60,
                height: 60,
                child: Icon(Icons.gif, color: Colors.white, size: 32),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'GIF ready to send',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Semantics(
            label: 'Close GIF preview',
            button: true,
            child: GestureDetector(
              onTap: () => setState(() => _pendingGifUrl = null),
              child: const Icon(Icons.close, color: Colors.white70, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: TextField(
                controller: _msgController,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge!.copyWith(fontSize: 15),
                strutStyle: const StrutStyle(
                  fontSize: 15,
                  height: 1.6,
                  forceStrutHeight: true,
                ),
                onChanged: (text) {
                  _typingTimer?.cancel();
                  final notifier = ref.read(chatNotifierProvider.notifier);
                  if (text.isNotEmpty) {
                    notifier.setTyping(true);
                    _typingTimer = Timer(const Duration(seconds: 3), () {
                      notifier.setTyping(false);
                    });
                  } else {
                    notifier.setTyping(false);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Type here ...',
                  hintStyle: const TextStyle(color: Colors.black38),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  suffixIcon: GestureDetector(
                    onTap: () async {
                      final gif = await showGifPicker(context);
                      if (!mounted) return;
                      if (gif != null) _sendGif(gif);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellowWarm,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'GIF',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            color: Color(0xFF4A3228),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            label: 'Send message',
            button: true,
            child: GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAC163),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/images/icons/sent.svg',
                  width: 24,
                  height: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Topic card with shuffle animation ────────────────────────────────────
class _TopicCard extends StatefulWidget {
  final String assetPath;
  final VoidCallback onShuffle;
  const _TopicCard({required this.assetPath, required this.onShuffle});

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.90), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.06), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.00), weight: 25),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _rotate = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.04), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.04), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.04, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleShuffle() {
    _ctrl.forward(from: 0);
    widget.onShuffle();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Transform.rotate(
              angle: _rotate.value,
              child: Transform.scale(scale: _scale.value, child: child),
            ),
            child: Image.asset(
              widget.assetPath,
              width: 180,
              errorBuilder: (_, _, _) => Container(
                width: 180,
                height: 260,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2E9DD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF5A443A), width: 4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          PressBounceBtn(
            onTap: _handleShuffle,
            scale: 0.92,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAC163),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
              child: const Text(
                'shuffle',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF6B5E5B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Group typing indicator ────────────────────────────────────────────────
class _GroupTypingIndicator extends StatefulWidget {
  const _GroupTypingIndicator();

  @override
  State<_GroupTypingIndicator> createState() => _GroupTypingIndicatorState();
}

class _GroupTypingIndicatorState extends State<_GroupTypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      ),
    );
    _anims = _controllers
        .map(
          (c) => Tween<double>(
            begin: 0,
            end: -7,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();
    _startLoop();
  }

  Future<void> _startLoop() async {
    while (mounted) {
      for (int i = 0; i < 3; i++) {
        if (!mounted) return;
        await _controllers[i].forward();
        if (!mounted) return;
        await _controllers[i].reverse();
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          LayeredAvatar(boxSize: 40),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFDCEBCE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(
                3,
                (i) => AnimatedBuilder(
                  animation: _anims[i],
                  builder: (_, _) => Transform.translate(
                    offset: Offset(0, _anims[i].value),
                    child: Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6B5E5B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
