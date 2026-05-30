import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/avatar_overlay.dart';
import '../shared/connectivity_provider.dart';
import '../shared/info_dialog.dart';
import '../shared/layered_avatar.dart';
import '../shared/offline_chip.dart';
import '../theme/app_colors.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/profile/presentation/providers/profile_provider.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  static const int _maxUsername = 20;
  static const int _maxInterest = 100;

  late TextEditingController _usernameCtrl;
  late TextEditingController _interestCtrl;
  bool _usernameError = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileNotifierProvider).profile;
    _usernameCtrl = TextEditingController(text: profile?.displayName ?? '');
    _interestCtrl = TextEditingController(text: profile?.interest ?? '');
    _usernameCtrl.addListener(() {
      if (_usernameError && _usernameCtrl.text.isNotEmpty) {
        setState(() => _usernameError = false);
      }
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileNotifierProvider);

    ref.listen<ProfileState>(profileNotifierProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(next.error!)));
      }
      if (prev?.profile == null && next.profile != null) {
        if (_usernameCtrl.text.isEmpty) {
          _usernameCtrl.text = next.profile?.displayName ?? '';
        }
        if (_interestCtrl.text.isEmpty) {
          _interestCtrl.text = next.profile?.interest ?? '';
        }
      }
    });

    final isOffline = !ref
        .watch(isOnlineProvider)
        .when(data: (v) => v, loading: () => true, error: (_, _) => true);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildCustomAppBar(context),
          const OfflineChip(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 30,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar preview
                              Center(
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 18),
                                      child: Center(
                                        child: LayeredAvatar(
                                          boxSize: 62,
                                          moodOverlay: ref
                                              .watch(avatarProvider)
                                              .mood,
                                          accessoryOverlay: ref
                                              .watch(avatarProvider)
                                              .accessory,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Username
                              ValueListenableBuilder(
                                valueListenable: _usernameCtrl,
                                builder: (_, val, _) => Row(
                                  children: [
                                    Text(
                                      'Username',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Do not use your real name',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall!
                                          .copyWith(
                                            fontSize: 11,
                                            color: const Color(0xFFD9453F),
                                          ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${val.text.length}/$_maxUsername',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                            fontSize: 12,
                                            color: Colors.black,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _usernameCtrl,
                                maxLength: _maxUsername,
                                hintText: 'What do you go by?',
                              ),
                              if (_usernameError) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '*Username is required',
                                  style: Theme.of(context).textTheme.labelSmall!
                                      .copyWith(
                                        fontSize: 11,
                                        color: const Color(0xFFD9453F),
                                      ),
                                ),
                              ],
                              const SizedBox(height: 24),

                              // Interest
                              ValueListenableBuilder(
                                valueListenable: _interestCtrl,
                                builder: (_, val, _) => Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Interest',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                    ),
                                    Text(
                                      '${val.text.length}/$_maxInterest',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                            fontSize: 12,
                                            color: Colors.black,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _interestCtrl,
                                maxLength: _maxInterest,
                                maxLines: 5,
                                hintText: 'What are you into?',
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),
                        const SizedBox(height: 24),

                        // Save button
                        GestureDetector(
                          onTap: state.isLoading
                              ? null
                              : () async {
                                  if (isOffline) {
                                    ScaffoldMessenger.of(context)
                                      ..clearSnackBars()
                                      ..showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "You're offline. Changes require a connection.",
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    return;
                                  }
                                  if (_usernameCtrl.text.trim().isEmpty) {
                                    setState(() => _usernameError = true);
                                    return;
                                  }
                                  final uid = ref
                                      .read(authNotifierProvider)
                                      .user
                                      ?.uid;
                                  if (uid == null) return;
                                  final navigator = Navigator.of(context);
                                  final notifier = ref.read(
                                    profileNotifierProvider.notifier,
                                  );
                                  await notifier.updateDisplayName(
                                    uid,
                                    _usernameCtrl.text.trim(),
                                  );
                                  if (!mounted) return;
                                  if (ref.read(profileNotifierProvider).error !=
                                      null) {
                                    return;
                                  }
                                  await notifier.updateInterest(
                                    uid,
                                    _interestCtrl.text.trim(),
                                  );
                                  if (!context.mounted) return;
                                  if (ref.read(profileNotifierProvider).error ==
                                      null) {
                                    showInfoDialog(
                                      context,
                                      type: InfoDialogType.success,
                                      title: 'Profile Saved',
                                      message:
                                          'Your profile has been updated successfully.',
                                      onConfirm: () => navigator.pop(),
                                    );
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isOffline
                                  ? Colors.grey.shade200
                                  : const Color(0xFFDEF1C2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isOffline
                                    ? Colors.grey.shade300
                                    : const Color(0xFFC7D2B5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: state.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : Text(
                                    'Save',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(
                                          color: isOffline
                                              ? Colors.grey.shade500
                                              : Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
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
              ),
              const SizedBox(width: 16),
              Text(
                'Edit Profile',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required int maxLength,
    int maxLines = 1,
    String hintText = '',
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, val, _) => Stack(
        children: [
          TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              counterText: '',
              hintText: hintText,
              hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: const Color(0xFF757575),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.fromLTRB(
                14,
                12,
                val.text.isNotEmpty ? 36 : 14,
                12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey, width: 1.5),
              ),
            ),
          ),
          if (val.text.isNotEmpty)
            Positioned(
              top: 6,
              right: 6,
              child: Semantics(
                label: 'Clear',
                button: true,
                child: GestureDetector(
                  onTap: () => controller.clear(),
                  child: SvgPicture.asset(
                    'assets/images/icons/Close.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      Colors.grey,
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
