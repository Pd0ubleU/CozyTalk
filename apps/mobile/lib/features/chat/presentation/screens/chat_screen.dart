import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/session_status.dart';
import '../../domain/entities/typing_user.dart';
import '../providers/chat_provider.dart';
import '../../../jukebox/presentation/widgets/jukebox_chat_player.dart';
import '../../../jukebox/presentation/widgets/jukebox_sheet.dart';
import '../../../report/presentation/screens/report_sheet.dart';
import '../../../card_shuffle/presentation/providers/card_shuffle_provider.dart';
import '../../../card_shuffle/domain/entities/icebreaker_question.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String currentUserId;
  final String? currentUserDisplayName;
  final String? currentUserPhotoUrl;
  final String? reportedUserId;

  const ChatScreen({
    super.key,
    required this.sessionId,
    required this.currentUserId,
    this.currentUserDisplayName,
    this.currentUserPhotoUrl,
    this.reportedUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _topicPanelVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatNotifierProvider.notifier)
          .enterSession(
            sessionId: widget.sessionId,
            currentUserId: widget.currentUserId,
            currentUserDisplayName: widget.currentUserDisplayName,
            currentUserPhotoUrl: widget.currentUserPhotoUrl,
          );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatNotifierProvider);

    ref.listen<ChatState>(chatNotifierProvider, (prev, next) {
      if (next.messages.length != (prev?.messages.length ?? 0)) {
        _scrollToBottom();
      }
    });

    if (state.status == SessionStatus.disconnected) {
      return const _DisconnectedScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CozyTalk'),
        actions: [
          Semantics(
            label: 'Open Jukebox',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.queue_music_rounded),
              tooltip: 'Jukebox',
              onPressed: state.status == SessionStatus.chatting
                  ? _openJukeboxSheet
                  : null,
            ),
          ),
          Semantics(
            label: 'Draw an icebreaker topic card',
            button: true,
            child: IconButton(
              icon: Icon(
                _topicPanelVisible ? Icons.style : Icons.style_outlined,
              ),
              tooltip: 'Topic',
              onPressed: _toggleTopicPanel,
            ),
          ),
          if (widget.reportedUserId != null)
            Semantics(
              label: 'Report this user',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.flag_outlined),
                tooltip: 'Report',
                onPressed: state.status == SessionStatus.chatting
                    ? _showReportSheet
                    : null,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          JukeboxChatPlayer(roomId: widget.sessionId),
          Expanded(
            child: state.messages.isEmpty
                ? const Center(
                    child: Text(
                      'Say hello!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      final isMine = message.senderId == state.currentUserId;
                      return _MessageBubble(
                        text: message.text,
                        displayName: message.displayName,
                        isMine: isMine,
                      );
                    },
                  ),
          ),
          if (state.typingUsers.isNotEmpty)
            _TypingIndicator(typingUsers: state.typingUsers),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                state.error!,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Colors.red,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (_topicPanelVisible)
            _TopicPanel(
              onClose: () => setState(() => _topicPanelVisible = false),
              onDraw: () =>
                  ref.read(cardShuffleNotifierProvider.notifier).draw(),
            ),
          _InputBar(
            controller: _controller,
            isSending: state.isSending,
            onChanged: _onTypingChanged,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  void _onTypingChanged(String value) {
    _typingTimer?.cancel();
    if (value.isNotEmpty) {
      ref.read(chatNotifierProvider.notifier).setTyping(true);
      _typingTimer = Timer(const Duration(seconds: 2), () {
        ref.read(chatNotifierProvider.notifier).setTyping(false);
      });
    } else {
      ref.read(chatNotifierProvider.notifier).setTyping(false);
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _typingTimer?.cancel();
    ref.read(chatNotifierProvider.notifier).setTyping(false);
    _controller.clear();
    ref.read(chatNotifierProvider.notifier).sendMessage(text);
  }

  void _openJukeboxSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => JukeboxSheet(roomId: widget.sessionId),
    );
  }

  void _toggleTopicPanel() {
    final nowVisible = !_topicPanelVisible;
    setState(() => _topicPanelVisible = nowVisible);
    if (nowVisible) {
      ref.read(cardShuffleNotifierProvider.notifier).draw();
    }
  }

  void _showReportSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReportSheet(
        sessionId: widget.sessionId,
        reportedUserId: widget.reportedUserId!,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text;
  final String displayName;
  final bool isMine;

  const _MessageBubble({
    required this.text,
    required this.displayName,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        label: '$displayName: $text',
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMine
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMine ? 16 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 16),
                  ),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isMine
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  final List<TypingUser> typingUsers;
  const _TypingIndicator({required this.typingUsers});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _dotAnimations = List.generate(3, _dotScale);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _dotScale(int index) {
    final start = index * 0.2;
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.4,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween(0.4), weight: 40),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start, (start + 0.6).clamp(0.0, 1.0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.typingUsers;
    if (users.isEmpty) return const SizedBox.shrink();

    final first = users.first;
    final semanticLabel = _buildLabel(users);

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 6),
        child: Semantics(
          label: semanticLabel,
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _UserAvatar(user: first),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return AnimatedBuilder(
                      animation: _dotAnimations[i],
                      builder: (context, _) => Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outline
                              .withValues(alpha: _dotAnimations[i].value),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _buildLabel(List<TypingUser> users) {
    if (users.isEmpty) return '';
    if (users.length == 1) return '${users[0].displayName} is typing…';
    if (users.length == 2) {
      return '${users[0].displayName} and ${users[1].displayName} are typing…';
    }
    return 'Several people are typing…';
  }
}

// ── User avatar ───────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  final TypingUser user;
  const _UserAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoUrl;
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';

    final ImageProvider? image =
        (photoUrl != null && photoUrl.startsWith('https://'))
        ? NetworkImage(photoUrl)
        : null;

    return CircleAvatar(
      radius: 16,
      backgroundImage: image,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: image == null
          ? Text(
              initial,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            )
          : null,
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Message input',
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  onSubmitted: (_) => onSend(),
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: 'Send message',
              button: true,
              child: SizedBox(
                width: 48,
                height: 48,
                child: isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: onSend,
                        icon: const Icon(Icons.send_rounded),
                        tooltip: 'Send',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Icebreaker topic panel (prototype) ────────────────────────────────────────

class _TopicPanel extends ConsumerWidget {
  final VoidCallback onClose;
  final Future<IcebreakerQuestion?> Function() onDraw;

  const _TopicPanel({required this.onClose, required this.onDraw});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardShuffleNotifierProvider);
    final question = state.currentQuestion;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.style_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Icebreaker Topic',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (question != null) ...[
                const SizedBox(width: 8),
                _DepthBadge(depth: question.depth),
              ],
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.isLoading)
            const Center(
              child: SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (question != null) ...[
            Text(
              question.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              question.category,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else
            Text(
              'Tap Next to draw a question.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: state.isLoading ? null : onDraw,
              child: const Text('Next Card'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DepthBadge extends StatelessWidget {
  final String depth;
  const _DepthBadge({required this.depth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color(depth).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color(depth).withValues(alpha: 0.5)),
      ),
      child: Text(
        depth,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color(depth),
        ),
      ),
    );
  }

  static Color _color(String depth) => switch (depth) {
    'light' => const Color(0xFF4CAF50),
    'medium' => const Color(0xFFFF9800),
    'deep' => const Color(0xFFBA5F3A),
    _ => const Color(0xFF4CAF50),
  };
}

// ── Disconnected screen ───────────────────────────────────────────────────────

class _DisconnectedScreen extends StatelessWidget {
  const _DisconnectedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.link_off_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Session ended',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'The conversation has ended.',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
