import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';
import '../models/friend.dart';
import '../dialogs/report_dialog.dart';
import '../shared/gif_picker.dart';
import '../shared/layered_avatar.dart';
import 'friend_profile_dialog.dart';
import 'widgets.dart';

// Mock conversation history per friend name — ready to swap with real API
final Map<String, List<ChatMessage>> _mockConversations = {
  'Nong Prae': [
    const ChatMessage(text: 'Hello', isMe: false, time: '10:00 pm'),
    const ChatMessage(text: 'Hello 😊🔥💕😊', isMe: true, time: '10:00 pm'),
  ],
  'Somjeed': [
    const ChatMessage(text: 'How are you?', isMe: false, time: '9:30 am'),
    const ChatMessage(text: "I'm good, thanks!", isMe: true, time: '9:31 am'),
    const ChatMessage(text: 'How are you?', isMe: false, time: '9:32 am'),
  ],
  'Platoo': [
    const ChatMessage(text: 'How are you?', isMe: false, time: '8:00 pm'),
  ],
};

class FriendChatScreen extends StatefulWidget {
  const FriendChatScreen({super.key});

  @override
  State<FriendChatScreen> createState() => _FriendChatScreenState();
}

class _FriendChatScreenState extends State<FriendChatScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  late Friend _friend;
  late List<ChatMessage> _messages;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is! Friend) {
        Navigator.pop(context);
        return;
      }
      _friend = args;
      _messages = List<ChatMessage>.from(
        _mockConversations[_friend.name] ??
            [
              ChatMessage(
                text: _friend.lastMessage,
                isMe: false,
                time: _formatNow(),
              ),
            ],
      );
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isMe: true, time: _formatNow()));
      _inputCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendGif(String label) {
    setState(() {
      _messages.add(
        ChatMessage(text: label, isMe: true, time: _formatNow(), isGif: true),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatNow() {
    final now = DateTime.now();
    final h = now.hour > 12
        ? now.hour - 12
        : now.hour == 0
        ? 12
        : now.hour;
    final m = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'pm' : 'am';
    return '$h:$m $ampm';
  }

  String _chatDateLabel() {
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          if (_friend.room != null && _friend.isOnline)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: FriendRoomCard(
                room: _friend.room!,
                showLabel: true,
                backgroundColor: Colors.white,
                onJoin: _friend.room!.canJoin
                    ? () => Navigator.pushNamed(
                        context,
                        AppRoutes.groupChatScreen,
                        arguments: {
                          'roomName': _friend.room!.name,
                          'bgImage': _friend.room!.thumbnail,
                        },
                      )
                    : null,
              ),
            ),
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildDateLabel(),
                _buildSafetyNotice(),
                const SizedBox(height: 8),
                ..._messages.map(_buildMessageBubble),
              ],
            ),
          ),
          _friend.isBlocked ? _buildBlockedBar() : _buildInputBar(),
        ],
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brownDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Back
                Semantics(
                  label: 'Go back',
                  button: true,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: SvgPicture.asset(
                        'assets/images/icons/Back.svg',
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Avatar — tappable to show profile
                Semantics(
                  label: 'View user profile',
                  button: true,
                  child: GestureDetector(
                    onTap: () => showFriendProfileDialog(
                      context: context,
                      friend: _friend,
                      onNoteSaved: (newNote) => setState(
                        () =>
                            _friend.note = newNote.isNotEmpty ? newNote : null,
                      ),
                    ),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.shade300,
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
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Center(
                            child: _friend.avatar.isNotEmpty
                                ? LayeredAvatar(boxSize: 34)
                                : const Icon(
                                    Icons.person,
                                    color: Colors.grey,
                                    size: 28,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name + online status (not tappable)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _friend.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _friend.isOnline
                                  ? const Color(0xFF86BA73)
                                  : Colors.grey.shade300,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _friend.isOnline
                                    ? const Color(0xFF72A161)
                                    : Colors.grey.shade400,
                                width: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _friend.isOnline ? 'Online' : 'Offline',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Report button
                Semantics(
                  label: 'Report user',
                  button: true,
                  child: GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const ReportDialog(),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCCAA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFCF5733),
                          width: 1.5,
                        ),
                      ),
                      child: SvgPicture.asset(
                        'assets/images/icons/Report.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFCF5733),
                          BlendMode.srcIn,
                        ),
                      ),
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

  // ─── Date label ───
  Widget _buildDateLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          _chatDateLabel(),
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // ─── Safety notice banner ───
  Widget _buildSafetyNotice() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.peachWarm,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.redOrange.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: Text(
        'Keep it friendly! Please be respectful and protect your personal info.\n'
        'Report any suspicious behavior to help keep our community safe.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 13,
          color: AppColors.brownDeep,
          height: 1.5,
        ),
      ),
    );
  }

  // ─── Message bubble ───
  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: message.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: message.isMe
                  ? const Color(0xFFF6D4E5)
                  : const Color(0xFFDEF1C2),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: message.isMe
                    ? const Radius.circular(18)
                    : const Radius.circular(4),
                bottomRight: message.isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(18),
              ),
              border: Border.all(
                color: message.isMe
                    ? const Color(0xFFF0BFD6)
                    : const Color(0xFFC7D2B5),
                width: 1.5,
              ),
            ),
            child: message.isGif
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.text,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4A3228),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellowWarm,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'GIF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A3228),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    message.text,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            message.time,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Blocked bar ───
  Widget _buildBlockedBar() {
    return Container(
      decoration: const BoxDecoration(color: AppColors.brownDeep),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          'You can no longer send messages in this chat.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─── Bottom input bar ───
  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(color: AppColors.brownDeep),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 58,
              padding: const EdgeInsets.only(left: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _inputCtrl,
                decoration: InputDecoration(
                  hintText: 'Type here ...',
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  suffixIcon: GestureDetector(
                    onTap: () async {
                      final gif = await showGifPicker(context);
                      if (!mounted) return;
                      if (gif != null) _sendGif(gif);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 14,
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
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
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.yellowWarm,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFD49A20),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  'assets/images/icons/sent.svg',
                  width: 26,
                  height: 26,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF695959),
                    BlendMode.srcIn,
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
