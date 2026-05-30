import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/screens/chat_screen.dart';
import '../../domain/entities/matchmaking_status.dart';
import '../../domain/entities/room.dart';
import '../providers/matchmaking_provider.dart';

/// Backend-testing screen — NOT part of the production UI.
/// Accessible via HelloScreen (_useMainUI = false) to verify all matchmaking
/// Cloud Functions work end-to-end.
class MatchmakingTestScreen extends ConsumerStatefulWidget {
  const MatchmakingTestScreen({super.key});

  @override
  ConsumerState<MatchmakingTestScreen> createState() =>
      _MatchmakingTestScreenState();
}

class _MatchmakingTestScreenState extends ConsumerState<MatchmakingTestScreen> {
  final List<TextEditingController> _idControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _idFocusNodes = List.generate(5, (_) => FocusNode());
  final TextEditingController _interestController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref
          .read(matchmakingNotifierProvider.notifier)
          .loadSavedInterestText();
      if (mounted) {
        _interestController.text = ref
            .read(matchmakingNotifierProvider)
            .interestText;
      }
    });
  }

  @override
  void dispose() {
    for (final c in _idControllers) {
      c.dispose();
    }
    for (final f in _idFocusNodes) {
      f.dispose();
    }
    _interestController.dispose();
    super.dispose();
  }

  String get _enteredRoomId => _idControllers.map((c) => c.text).join();

  void _clearIdFields() {
    for (final c in _idControllers) {
      c.clear();
    }
    _idFocusNodes.first.requestFocus();
  }

  void _enterChat(BuildContext context, String roomId) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(sessionId: roomId, currentUserId: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchmakingNotifierProvider);
    final notifier = ref.read(matchmakingNotifierProvider.notifier);
    final isBusy =
        state.status == MatchmakingStatus.searching ||
        state.status == MatchmakingStatus.waiting1v1 ||
        state.status == MatchmakingStatus.creating;
    final isMatched = state.status == MatchmakingStatus.matched;
    final room = state.currentRoom;

    return Scaffold(
      appBar: AppBar(title: const Text('Matchmaking Test')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusCard(state: state),
              const SizedBox(height: 20),
              TextField(
                key: const Key('interest_text_field'),
                controller: _interestController,
                enabled: !isBusy && !isMatched,
                decoration: const InputDecoration(
                  labelText: 'Interest (optional)',
                  hintText: 'e.g. football, cooking, music…',
                  border: OutlineInputBorder(),
                ),
                onChanged: notifier.setInterestText,
              ),
              const SizedBox(height: 12),
              _ThemeSelector(
                selected: state.backgroundTheme,
                enabled: !isBusy && !isMatched,
                onChanged: notifier.setBackgroundTheme,
              ),
              const SizedBox(height: 12),
              _ActionButtons(
                isBusy: isBusy,
                isMatched: isMatched,
                onFindGroup: () => notifier.joinGroupRoom(),
                onFind1v1: () => notifier.join1v1Pool(),
                onCreateCustom: () => notifier.createCustomRoom(),
                onCancel: () => notifier.cancelSearch(),
              ),
              const SizedBox(height: 20),
              _JoinByIdRow(
                controllers: _idControllers,
                focusNodes: _idFocusNodes,
                isBusy: isBusy,
                onJoin: () {
                  final id = _enteredRoomId;
                  if (id.length == 5) {
                    notifier.joinRoomById(id);
                    _clearIdFields();
                  }
                },
              ),
              if (isMatched) ...[
                const SizedBox(height: 20),
                _RoomActions(
                  room: room,
                  roomId: state.roomId!,
                  onLeave: () => notifier.leaveRoom(),
                  onToggleLock: (v) => notifier.setRoomLock(isLocked: v),
                  onEnterChat: () => _enterChat(context, state.roomId!),
                ),
              ],
              if (state.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              const _DebugPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final MatchmakingState state;
  const _StatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final room = state.currentRoom;
    final label = _statusLabel(state.status);
    final color = _statusColor(state.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                if (state.status == MatchmakingStatus.searching ||
                    state.status == MatchmakingStatus.waiting1v1 ||
                    state.status == MatchmakingStatus.creating) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            if (state.roomId != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Room ID: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    state.roomId!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        Clipboard.setData(ClipboardData(text: state.roomId!)),
                    child: const Icon(Icons.copy, size: 16),
                  ),
                ],
              ),
            ],
            if (room != null) ...[
              const SizedBox(height: 6),
              Text(
                'Members: ${room.memberCount}/${room.maxUsers}  '
                '·  ${room.roomType.name}  ·  ${room.mode.name}  '
                '·  ${room.isLocked ? "🔒 locked" : "🔓 unlocked"}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              if (state.isNewRoom && room.memberCount < 2)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Waiting for a second person to join…',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _statusLabel(MatchmakingStatus s) {
    switch (s) {
      case MatchmakingStatus.idle:
        return 'Idle';
      case MatchmakingStatus.searching:
        return 'Searching…';
      case MatchmakingStatus.waiting1v1:
        return 'Waiting for 1v1 match…';
      case MatchmakingStatus.matched:
        return 'In Room';
      case MatchmakingStatus.creating:
        return 'Creating room…';
      case MatchmakingStatus.error:
        return 'Error';
    }
  }

  static Color _statusColor(MatchmakingStatus s) {
    switch (s) {
      case MatchmakingStatus.idle:
        return Colors.grey;
      case MatchmakingStatus.searching:
      case MatchmakingStatus.waiting1v1:
      case MatchmakingStatus.creating:
        return Colors.orange;
      case MatchmakingStatus.matched:
        return Colors.green;
      case MatchmakingStatus.error:
        return Colors.red;
    }
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isBusy;
  final bool isMatched;
  final VoidCallback onFindGroup;
  final VoidCallback onFind1v1;
  final VoidCallback onCreateCustom;
  final VoidCallback onCancel;

  const _ActionButtons({
    required this.isBusy,
    required this.isMatched,
    required this.onFindGroup,
    required this.onFind1v1,
    required this.onCreateCustom,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: isBusy || isMatched ? null : onFind1v1,
                child: const Text('Find 1v1'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: isBusy ? onCancel : null,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: isBusy || isMatched ? null : onFindGroup,
          child: const Text('Find Group Room'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: isBusy || isMatched ? null : onCreateCustom,
          child: const Text('Create Custom Room'),
        ),
      ],
    );
  }
}

// ── Background theme selector ─────────────────────────────────────────────────

const _kThemes = [
  (id: 'kao_tapu', label: 'Kao Tapu'),
  (id: 'red_lotus_lake', label: 'Red Lotus Lake'),
  (id: 'sea_of_cloud', label: 'Sea of Cloud'),
  (id: 'lumphini_park', label: 'Lumphini Park'),
];

class _ThemeSelector extends StatelessWidget {
  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _ThemeSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Room theme (optional)',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _kThemes.map((theme) {
            final isSelected = selected == theme.id;
            return FilterChip(
              key: Key('theme_chip_${theme.id}'),
              label: Text(theme.label),
              selected: isSelected,
              onSelected: enabled
                  ? (_) => onChanged(isSelected ? null : theme.id)
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _JoinByIdRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool isBusy;
  final VoidCallback onJoin;

  const _JoinByIdRow({
    required this.controllers,
    required this.focusNodes,
    required this.isBusy,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 4 ? 6 : 12),
              child: TextField(
                key: Key('room_id_field_$i'),
                controller: controllers[i],
                focusNode: focusNodes[i],
                autofocus: false,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                maxLength: 1,
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) {
                  if (v.isNotEmpty && i < 4) {
                    focusNodes[i + 1].requestFocus();
                  }
                  if (v.isEmpty && i > 0) {
                    focusNodes[i - 1].requestFocus();
                  }
                },
              ),
            ),
          );
        }),
        FilledButton(
          onPressed: isBusy ? null : onJoin,
          child: const Text('Join by ID'),
        ),
      ],
    );
  }
}

// ── Dev-only debug panel ──────────────────────────────────────────────────────

class _DebugPanel extends ConsumerStatefulWidget {
  const _DebugPanel();

  @override
  ConsumerState<_DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends ConsumerState<_DebugPanel> {
  bool _expanded = true;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    // Start listening for state changes via ref.listen inside build,
    // so we use a post-frame callback to capture the first state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final s = ref.read(matchmakingNotifierProvider);
        _appendLog(s);
      }
    });
  }

  void _appendLog(MatchmakingState s) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final entry =
        '[$ts] ${s.status.name}'
        '${s.roomId != null ? ' | room=${s.roomId}' : ''}'
        '${s.error != null ? ' | ERR=${s.error}' : ''}';
    setState(() {
      _log.add(entry);
      if (_log.length > 30) _log.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MatchmakingState>(matchmakingNotifierProvider, (_, next) {
      _appendLog(next);
    });

    final state = ref.watch(matchmakingNotifierProvider);
    final room = state.currentRoom;
    String uid = '—';
    try {
      uid = FirebaseAuth.instance.currentUser?.uid ?? '—';
    } catch (_) {}

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF444466)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    '⚙ Dev Panel',
                    style: TextStyle(
                      color: Color(0xFF8888CC),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _expanded ? '▲' : '▼',
                    style: const TextStyle(
                      color: Color(0xFF8888CC),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Color(0xFF333355), height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFFCCCCEE),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('uid', uid, maxLen: 28),
                    _row('status', state.status.name),
                    _row('theme', state.backgroundTheme ?? 'randomized'),
                    _row('roomId', state.roomId ?? '—'),
                    _row('isNewRoom', state.isNewRoom.toString()),
                    if (room != null) ...[
                      _row('count', '${room.memberCount} of ${room.maxUsers}'),
                      _row('roomMode', room.mode.name),
                      _row('roomType', room.roomType.name),
                      _row('roomStatus', room.status.name),
                      _row('locked', room.isLocked.toString()),
                    ],
                    if (state.error != null)
                      _row(
                        'error',
                        state.error!,
                        color: const Color(0xFFFF6666),
                      ),
                    const SizedBox(height: 6),
                    const Text(
                      '── log ──',
                      style: TextStyle(color: Color(0xFF666688)),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        reverse: true,
                        itemCount: _log.length,
                        itemBuilder: (_, i) => Text(
                          _log[_log.length - 1 - i],
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _row(
    String label,
    String value, {
    Color? color,
    int maxLen = 40,
  }) {
    final display = value.length > maxLen
        ? '${value.substring(0, maxLen)}…'
        : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$label: $display',
        style: TextStyle(color: color ?? const Color(0xFFCCCCEE)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RoomActions extends StatelessWidget {
  final Room? room;
  final String roomId;
  final VoidCallback onLeave;
  final ValueChanged<bool> onToggleLock;
  final VoidCallback onEnterChat;

  const _RoomActions({
    required this.room,
    required this.roomId,
    required this.onLeave,
    required this.onToggleLock,
    required this.onEnterChat,
  });

  @override
  Widget build(BuildContext context) {
    final isCustom = room?.roomType == RoomType.custom;
    final isLocked = room?.isLocked ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: onEnterChat,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Enter Chat ↗'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onLeave,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Leave Room'),
                  ),
                ),
                if (isCustom) ...[
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 18),
                      const SizedBox(width: 4),
                      Switch(value: isLocked, onChanged: onToggleLock),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
