import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/avatar/presentation/providers/avatar_decoration_provider.dart';
import '../features/friends/presentation/providers/friends_provider.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import '../shared/offline_chip.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';
import '../shared/avatar_overlay.dart';
import 'thought_bubble_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final uid = ref.read(authNotifierProvider).user?.uid;
    if (uid != null) {
      Future.microtask(() {
        ref.read(profileNotifierProvider.notifier).load(uid);
        ref.read(avatarDecorationNotifierProvider.notifier).load(uid);
      });
    }
  }

  Future<void> _navigateMood() async {
    final uid = ref.read(authNotifierProvider).user?.uid;
    final result = await Navigator.pushNamed(context, AppRoutes.mood);
    if (result is String && mounted && uid != null) {
      await ref
          .read(avatarDecorationNotifierProvider.notifier)
          .updateMood(uid, result);
    }
  }

  Future<void> _navigateDressUp() async {
    final uid = ref.read(authNotifierProvider).user?.uid;
    final result = await Navigator.pushNamed(context, AppRoutes.dressUp);
    if (result is String && mounted && uid != null) {
      await ref
          .read(avatarDecorationNotifierProvider.notifier)
          .updateHat(uid, result);
    }
  }

  void _editThoughts() async {
    final uid = ref.read(authNotifierProvider).user?.uid;
    final result = await showThoughtBubbleDialog(
      context: context,
      initialText: ref.read(profileNotifierProvider).profile?.thoughts ?? '',
    );
    if (result != null && mounted && uid != null) {
      ref.read(profileNotifierProvider.notifier).updateThoughts(uid, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AvatarDecorationState>(avatarDecorationNotifierProvider, (
      prev,
      next,
    ) {
      // Fire on every transition into an error state (prev.error may be
      // non-null too because _resetErrorIfAny clears and re-sets on each
      // repeated offline attempt — we just need error to be present now).
      if (next.error != null && next.error != prev?.error && context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(next.error!),
              backgroundColor: AppColors.brownDeep,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _TopBar(
            hasNotification: ref
                .watch(friendsNotifierProvider)
                .incomingRequests
                .isNotEmpty,
            onBellTap: () =>
                Navigator.pushNamed(context, AppRoutes.notification),
            onUserTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
          const OfflineChip(),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 35),

                    Text(
                      'Hello, ${ref.watch(profileNotifierProvider).profile?.displayName ?? ''}!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 8),

                    _AvatarCard(
                      moodText:
                          ref
                              .watch(profileNotifierProvider)
                              .profile
                              ?.thoughts ??
                          '',
                      onMoodTap: _editThoughts,
                      moodOverlay: ref.watch(avatarProvider).mood,
                      accessoryOverlay: ref.watch(avatarProvider).accessory,
                    ),
                    const SizedBox(height: 22),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _QuickAction(
                          imagePath: 'assets/images/icons/DressUp.svg',
                          label: 'Dress Up!',
                          imageWidth: 35,
                          imageHeight: 35,
                          onTap: _navigateDressUp,
                        ),
                        _QuickAction(
                          imagePath: 'assets/images/icons/Mood.svg',
                          label: 'Mood',
                          imageWidth: 38,
                          imageHeight: 38,
                          onTap: _navigateMood,
                        ),
                        _QuickAction(
                          imagePath: 'assets/images/icons/Friends.svg',
                          label: 'Friends',
                          imageWidth: 39,
                          imageHeight: 39,
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.friends),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    // Let's chat
                    Center(
                      child: _LetsChatButton(
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.chooseRoomType,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TOP BAR ───────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final bool hasNotification;
  final VoidCallback onBellTap;
  final VoidCallback onUserTap;

  const _TopBar({
    required this.hasNotification,
    required this.onBellTap,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF695959),
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
              Image.asset(
                'assets/images/Logo.png',
                height: 70,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Text(
                    'CozyTalk',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  );
                },
              ),
              const Spacer(),

              Stack(
                clipBehavior: Clip.none,
                children: [
                  Semantics(
                    label: 'Notifications',
                    button: true,
                    child: GestureDetector(
                      onTap: onBellTap,
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
                          'assets/images/icons/Notification.svg',
                          width: 25,
                          height: 25,
                        ),
                      ),
                    ),
                  ),
                  if (hasNotification)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCF5733),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFA33615),
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 14),

              Semantics(
                label: 'View profile',
                button: true,
                child: GestureDetector(
                  onTap: onUserTap,
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
                      'assets/images/icons/User.svg',
                      width: 27,
                      height: 27,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarCard extends StatefulWidget {
  final String moodText;
  final VoidCallback onMoodTap;
  final AvatarOverlay? moodOverlay;
  final AvatarOverlay? accessoryOverlay;

  const _AvatarCard({
    required this.moodText,
    required this.onMoodTap,
    this.moodOverlay,
    this.accessoryOverlay,
  });

  @override
  State<_AvatarCard> createState() => _AvatarCardState();
}

class _AvatarCardState extends State<_AvatarCard> {
  Offset _bubblePosition = const Offset(210, 80);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 270,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double safeX = _bubblePosition.dx.clamp(
              0.0,
              constraints.maxWidth - 90.0,
            );
            double safeY = _bubblePosition.dy.clamp(
              0.0,
              constraints.maxHeight - 100.0,
            );

            // Avatar is 90px tall, positioned at bottom 62.
            // avatarTop = cardHeight(270) - 62 - 90 = 118
            // avatarCenterX = constraints.maxWidth / 2
            final double centerX = constraints.maxWidth / 2;

            return Stack(
              children: [
                // Background
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.15,
                    child: Image.asset(
                      'assets/images/backgrounds/HomeBg.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, _, _) =>
                          Container(color: AppColors.tanGreen),
                    ),
                  ),
                ),

                // Base avatar
                Positioned(
                  top: 118,
                  left: centerX - 45,
                  child: Image.asset(
                    'assets/images/UserAvatar.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: AppColors.brownDeep,
                      ),
                    ),
                  ),
                ),

                // Accessory layer — hats go under mood
                if (widget.accessoryOverlay != null &&
                    !widget.accessoryOverlay!.aboveMood)
                  Positioned(
                    top: widget.accessoryOverlay!.top,
                    left:
                        centerX +
                        widget.accessoryOverlay!.cx -
                        widget.accessoryOverlay!.w / 2,
                    child: Image.asset(
                      widget.accessoryOverlay!.path,
                      width: widget.accessoryOverlay!.w,
                      height: widget.accessoryOverlay!.h,
                      fit: BoxFit.contain,
                    ),
                  ),

                // Mood layer
                if (widget.moodOverlay != null)
                  Positioned(
                    top: widget.moodOverlay!.top,
                    left:
                        centerX +
                        widget.moodOverlay!.cx -
                        widget.moodOverlay!.w / 2,
                    child: Image.asset(
                      widget.moodOverlay!.path,
                      width: widget.moodOverlay!.w,
                      height: widget.moodOverlay!.h,
                      fit: BoxFit.contain,
                    ),
                  ),

                // Accessory layer — above mood (glasses)
                if (widget.accessoryOverlay != null &&
                    widget.accessoryOverlay!.aboveMood)
                  Positioned(
                    top: widget.accessoryOverlay!.top,
                    left:
                        centerX +
                        widget.accessoryOverlay!.cx -
                        widget.accessoryOverlay!.w / 2,
                    child: Image.asset(
                      widget.accessoryOverlay!.path,
                      width: widget.accessoryOverlay!.w,
                      height: widget.accessoryOverlay!.h,
                      fit: BoxFit.contain,
                    ),
                  ),

                // Draggable thought bubble
                Positioned(
                  left: safeX,
                  top: safeY,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        double newX = _bubblePosition.dx + details.delta.dx;
                        double newY = _bubblePosition.dy + details.delta.dy;
                        newX = newX.clamp(0.0, constraints.maxWidth - 90.0);
                        newY = newY.clamp(0.0, constraints.maxHeight - 100.0);
                        _bubblePosition = Offset(newX, newY);
                      });
                    },
                    child: _ThoughtBubble(
                      text: widget.moodText,
                      onTap: widget.onMoodTap,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── THOUGHT BUBBLE WIDGET ─────────────────────────────────────
class _ThoughtBubble extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _ThoughtBubble({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Edit thought bubble',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 90,
          height: 100,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/ThinkBubble.png'),
              fit: BoxFit.contain,
            ),
          ),
          padding: const EdgeInsets.only(bottom: 12, left: 15, right: 10),
          alignment: Alignment.center,
          child: Text(
            text.isEmpty ? 'Care to share?' : text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: text.isEmpty ? Colors.grey.shade400 : Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ─── QUICK ACTION BUTTON ────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final String imagePath;
  final String label;
  final VoidCallback onTap;

  final double imageWidth;
  final double imageHeight;

  const _QuickAction({
    required this.imagePath,
    required this.label,
    required this.onTap,
    this.imageWidth = 35,
    this.imageHeight = 35,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: SvgPicture.asset(
              imagePath,
              width: imageWidth,
              height: imageHeight,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── LET'S CHAT BUTTON ─────────────────────────────────────────
class _LetsChatButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LetsChatButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/icons/LetsChat.svg',
              width: 42,
              height: 42,
            ),
            const SizedBox(width: 12),
            const Text(
              "Let's chat!",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
