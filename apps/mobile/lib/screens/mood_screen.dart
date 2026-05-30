import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/avatar/presentation/providers/avatar_decoration_provider.dart';
import '../theme/app_colors.dart';
import '../shared/avatar_overlay.dart';
import '../shared/layered_avatar.dart';
import 'widgets.dart';

class _MoodOption {
  final String name;
  final String imagePath;
  const _MoodOption(this.name, this.imagePath);
}

class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key});

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  String? _selected;
  final List<String?> _history = [];
  final List<String?> _future = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final moodKey = ref
          .read(avatarDecorationNotifierProvider)
          .decoration
          ?.moodKey;
      setState(() => _selected = moodKey ?? 'Happy');
    });
  }

  static const List<_MoodOption> _moods = [
    _MoodOption('Happy', 'assets/images/moods/Happy.png'),
    _MoodOption('Thrilled', 'assets/images/moods/Thrilled.png'),
    _MoodOption('Sad', 'assets/images/moods/Sad.png'),
    _MoodOption('Lonely', 'assets/images/moods/Lonely.png'),
    _MoodOption('Silly', 'assets/images/moods/Silly.png'),
    _MoodOption('Grumpy', 'assets/images/moods/Grumpy.png'),
  ];

  void _select(String name) {
    setState(() {
      _history.add(_selected);
      _future.clear();
      _selected = name;
    });
    ref.read(avatarProvider.notifier).setMood(AvatarOverlays.mood[name]);
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _future.add(_selected);
      _selected = _history.removeLast();
    });
  }

  void _redo() {
    if (_future.isEmpty) return;
    setState(() {
      _history.add(_selected);
      _selected = _future.removeLast();
    });
  }

  void _delete() {
    if (_selected == null) return;
    setState(() {
      _history.add(_selected);
      _future.clear();
      _selected = null;
    });
    ref.read(avatarProvider.notifier).setMood(null);
  }

  Future<void> _save() async {
    if (ref.read(avatarDecorationNotifierProvider).status ==
        AvatarDecorationStatus.saving) {
      return;
    }
    final uid = ref.read(authNotifierProvider).user?.uid;
    if (uid == null || !mounted) return;
    await ref
        .read(avatarDecorationNotifierProvider.notifier)
        .updateMood(uid, _selected);
    if (mounted && ref.read(avatarDecorationNotifierProvider).error == null) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AvatarDecorationState>(avatarDecorationNotifierProvider, (
      prev,
      next,
    ) {
      if (next.error != null && next.error != prev?.error && context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(next.error!),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });
    final isSaving =
        ref.watch(avatarDecorationNotifierProvider).status ==
        AvatarDecorationStatus.saving;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Stack(
        children: [
          Column(
            children: [
              _buildCustomAppBar(context),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/backgrounds/MoodBg.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) =>
                                Container(color: AppColors.tanGreen),
                          ),
                        ),
                        Positioned(
                          bottom: -15,
                          child: LayeredAvatar(
                            boxSize: 130,
                            accessoryOverlay: ref
                                .watch(avatarProvider)
                                .accessory,
                            moodOverlay: _selected != null
                                ? AvatarOverlays.mood[_selected]
                                : ref.watch(avatarProvider).mood,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AvatarActionButton(
                      svgPath: 'assets/images/icons/Undo.svg',
                      enabled: _history.isNotEmpty,
                      onTap: _undo,
                      semanticLabel: 'Undo',
                    ),
                    const SizedBox(width: 12),
                    AvatarActionButton(
                      svgPath: 'assets/images/icons/Redo.svg',
                      enabled: _future.isNotEmpty,
                      onTap: _redo,
                      semanticLabel: 'Redo',
                    ),
                    const SizedBox(width: 12),
                    AvatarActionButton(
                      svgPath: 'assets/images/icons/Trash.svg',
                      enabled: _selected != null,
                      onTap: _delete,
                      semanticLabel: 'Reset mood',
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: _moods.length,
                    itemBuilder: (_, i) {
                      final mood = _moods[i];
                      final sel = _selected == mood.name;
                      return GestureDetector(
                        onTap: () => _select(mood.name),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          transform: Matrix4.translationValues(
                            0,
                            sel ? -10.0 : 0,
                            0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: sel
                                  ? const Color(0xFFCE5E42)
                                  : Colors.grey.shade300,
                              width: sel ? 2.5 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                mood.imagePath,
                                height: 45,
                                width: 45,
                                fit: BoxFit.contain,
                                errorBuilder: (_, e, s) => const Icon(
                                  Icons.sentiment_satisfied,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                mood.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: isSaving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDEF1C2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFC7D2B5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
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
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SvgPicture.asset(
                    'assets/images/icons/Back.svg',
                    width: 26,
                    height: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Mood',
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
    );
  }
}
