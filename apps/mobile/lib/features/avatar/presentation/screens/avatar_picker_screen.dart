import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/avatar_overlay.dart';
import '../../../../shared/layered_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/avatar_decoration_provider.dart';

class AvatarPickerScreen extends ConsumerStatefulWidget {
  const AvatarPickerScreen({super.key});

  @override
  ConsumerState<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends ConsumerState<AvatarPickerScreen> {
  // Pending selections — null means "no hat / no mood".
  // _*Changed flags distinguish "user explicitly chose None" from "untouched".
  String? _pendingHatKey;
  bool _hatChanged = false;
  String? _pendingMoodKey;
  bool _moodChanged = false;

  bool _isSaving = false;

  static const List<_Item> _hats = [
    _Item('Cap', 'Cap'),
    _Item('Beanie', 'Beanie'),
    _Item('Witch Hat', 'Witch'),
    _Item('Sunglasses', 'Glasses'),
    _Item('Cat Headband', 'Cat Headband'),
    _Item('Crown', 'Crown'),
  ];

  static const List<_Item> _moods = [
    _Item('Happy', 'Happy'),
    _Item('Thrilled', 'Thrilled'),
    _Item('Sad', 'Sad'),
    _Item('Lonely', 'Lonely'),
    _Item('Silly', 'Silly'),
    _Item('Grumpy', 'Grumpy'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authNotifierProvider).user?.uid;
      if (uid != null) {
        ref.read(avatarDecorationNotifierProvider.notifier).load(uid);
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final uid = ref.read(authNotifierProvider).user?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    final notifier = ref.read(avatarDecorationNotifierProvider.notifier);

    // If both hat and mood changed, update atomically
    if (_hatChanged && _moodChanged) {
      await notifier.updateDecoration(uid, _pendingHatKey, _pendingMoodKey);
    } else if (_hatChanged) {
      await notifier.updateHat(uid, _pendingHatKey);
    } else if (_moodChanged) {
      await notifier.updateMood(uid, _pendingMoodKey);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ref.read(avatarDecorationNotifierProvider).status !=
        AvatarDecorationStatus.error) {
      Navigator.of(context).pop();
    }
    // On error, stay on screen — the error banner is shown in the body.
  }

  @override
  Widget build(BuildContext context) {
    final providerState = ref.watch(avatarDecorationNotifierProvider);
    final status = providerState.status;
    final decoration = providerState.decoration;

    final isLoadingInitial =
        status == AvatarDecorationStatus.loading && decoration == null;

    // Use pending values when the user has made a local choice; fall back to
    // whatever is in Firestore (decoration) otherwise.
    final previewHatKey = _hatChanged ? _pendingHatKey : decoration?.hatKey;
    final previewMoodKey = _moodChanged ? _pendingMoodKey : decoration?.moodKey;
    final previewHat = previewHatKey != null
        ? AvatarOverlays.accessory[previewHatKey]
        : null;
    final previewMood = previewMoodKey != null
        ? AvatarOverlays.mood[previewMoodKey]
        : null;

    final isBusy = _isSaving || status == AvatarDecorationStatus.saving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Avatar'),
        actions: [
          if (isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Semantics(
              label: 'Save avatar',
              button: true,
              child: TextButton(onPressed: _save, child: const Text('Save')),
            ),
        ],
      ),
      body: isLoadingInitial
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // ── Avatar preview ──────────────────────────────────────
                Center(
                  child: Semantics(
                    label: 'Avatar preview',
                    child: LayeredAvatar(
                      boxSize: 120,
                      accessoryOverlay: previewHat,
                      moodOverlay: previewMood,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Hat section ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Hat',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _PickerRow(
                  items: _hats,
                  overlays: AvatarOverlays.accessory,
                  selectedKey: _hatChanged
                      ? _pendingHatKey
                      : decoration?.hatKey,
                  onClear: () => setState(() {
                    _pendingHatKey = null;
                    _hatChanged = true;
                  }),
                  onSelect: (key) => setState(() {
                    _pendingHatKey = key;
                    _hatChanged = true;
                  }),
                ),

                const SizedBox(height: 24),

                // ── Mood section ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Mood',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _PickerRow(
                  items: _moods,
                  overlays: AvatarOverlays.mood,
                  selectedKey: _moodChanged
                      ? _pendingMoodKey
                      : decoration?.moodKey,
                  onClear: () => setState(() {
                    _pendingMoodKey = null;
                    _moodChanged = true;
                  }),
                  onSelect: (key) => setState(() {
                    _pendingMoodKey = key;
                    _moodChanged = true;
                  }),
                ),

                const SizedBox(height: 32),

                // ── Error banner ────────────────────────────────────────
                if (status == AvatarDecorationStatus.error &&
                    providerState.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      providerState.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Internal helpers ───────────────────────────────────────────────────────

class _Item {
  final String label;
  final String key;
  const _Item(this.label, this.key);
}

class _PickerRow extends StatelessWidget {
  final List<_Item> items;
  final Map<String, AvatarOverlay> overlays;
  final String? selectedKey;
  final VoidCallback onClear;
  final ValueChanged<String> onSelect;

  const _PickerRow({
    required this.items,
    required this.overlays,
    required this.selectedKey,
    required this.onClear,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // +1 for the "None" tile at index 0
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _NoneTile(isSelected: selectedKey == null, onTap: onClear);
          }
          final item = items[index - 1];
          final overlay = overlays[item.key];
          return _AssetTile(
            label: item.label,
            assetPath: overlay?.path,
            isSelected: selectedKey == item.key,
            onTap: () => onSelect(item.key),
          );
        },
      ),
    );
  }
}

class _NoneTile extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _NoneTile({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'No selection',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 80,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              width: isSelected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 28, color: Colors.grey),
              const SizedBox(height: 6),
              Text(
                'None',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final String label;
  final String? assetPath;
  final bool isSelected;
  final VoidCallback onTap;

  const _AssetTile({
    required this.label,
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 80,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              width: isSelected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (assetPath != null)
                Image.asset(
                  assetPath!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.image_not_supported, size: 28),
                )
              else
                const Icon(Icons.image_not_supported, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
