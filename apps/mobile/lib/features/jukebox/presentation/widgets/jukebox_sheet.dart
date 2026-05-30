import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/jukebox_provider.dart';
import 'queue_slot_tile.dart';

class JukeboxSheet extends ConsumerStatefulWidget {
  final String roomId;
  const JukeboxSheet({super.key, required this.roomId});

  @override
  ConsumerState<JukeboxSheet> createState() => _JukeboxSheetState();
}

class _JukeboxSheetState extends ConsumerState<JukeboxSheet> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Safety net: re-subscribe if JukeboxPlayer's subscription errored.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(jukeboxNotifierProvider.notifier).enterRoom(widget.roomId);
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jukeboxNotifierProvider);
    final roomState = state.roomState;
    final notifier = ref.read(jukeboxNotifierProvider.notifier);

    ref.listen<JukeboxUiState>(jukeboxNotifierProvider, (prev, next) {
      // Show errors as a SnackBar so they're visible regardless of scroll.
      if (next.resolveError != null &&
          next.resolveError != prev?.resolveError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.resolveError!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      // Clear controller after successful add (urlInput reset to '').
      if (!next.isResolving &&
          next.resolveError == null &&
          next.urlInput.isEmpty &&
          _urlController.text.isNotEmpty) {
        _urlController.clear();
      }
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.queue_music_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Jukebox',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // ── Now Playing ──
                if (roomState?.currentTrack != null) ...[
                  Text(
                    'NOW PLAYING',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: roomState!.currentTrack!.artworkUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Icon(
                          Icons.music_note,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    title: Text(
                      roomState.currentTrack!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      roomState.currentTrack!.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _PlaybackPosition(
                          startedAt: roomState.startedAt,
                          pausedAt: roomState.pausedAt,
                          isPlaying: roomState.isPlaying,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Semantics(
                        label: roomState.isPlaying ? 'Pause' : 'Play',
                        button: true,
                        child: IconButton(
                          iconSize: 36,
                          icon: Icon(
                            roomState.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          onPressed: () =>
                              notifier.setPlaying(!roomState.isPlaying),
                        ),
                      ),
                      Semantics(
                        label: 'Skip track',
                        button: true,
                        child: IconButton(
                          iconSize: 36,
                          icon: Icon(
                            Icons.skip_next_rounded,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          onPressed: notifier.skip,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No track playing. Add one below.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],

                // ── Up Next ──
                Text(
                  'UP NEXT',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(3, (i) {
                  final queueIdx = (roomState?.currentIndex ?? 0) + 1 + i;
                  final track = (roomState?.queue.length ?? 0) > queueIdx
                      ? roomState!.queue[queueIdx]
                      : null;
                  if (track == null) {
                    return Container(
                      height: 56,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Empty slot',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    );
                  }
                  return QueueSlotTile(
                    track: track,
                    onRemove: () => notifier.removeFromQueue(queueIdx),
                  );
                }),
                const SizedBox(height: 16),

                // ── Add Song ──
                Text(
                  'ADD SONG',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'youtube.com/watch?v=...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (state.isResolving)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _urlController,
                        builder: (_, value, _) {
                          final hasText = value.text.trim().isNotEmpty;
                          final queueFull = (roomState?.queue.length ?? 0) >= 4;
                          return Semantics(
                            label: 'Add song to queue',
                            button: true,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Add URL'),
                              onPressed: (hasText && !queueFull)
                                  ? () => notifier.addUrl(
                                      _urlController.text.trim(),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live playback position display ────────────────────────────────────────────

class _PlaybackPosition extends StatefulWidget {
  final int startedAt;
  final int pausedAt;
  final bool isPlaying;

  const _PlaybackPosition({
    required this.startedAt,
    required this.pausedAt,
    required this.isPlaying,
  });

  @override
  State<_PlaybackPosition> createState() => _PlaybackPositionState();
}

class _PlaybackPositionState extends State<_PlaybackPosition> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_PlaybackPosition old) {
    super.didUpdateWidget(old);
    if (old.isPlaying != widget.isPlaying ||
        old.startedAt != widget.startedAt) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.isPlaying) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawSeconds = widget.isPlaying
        ? (DateTime.now().millisecondsSinceEpoch - widget.startedAt) ~/ 1000
        : widget.pausedAt ~/ 1000;
    final seconds = rawSeconds.clamp(0, 86400);
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return Text(
      '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.outline,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
