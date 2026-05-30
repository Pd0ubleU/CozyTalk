import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';

class ChooseRoomTypeScreen extends StatefulWidget {
  const ChooseRoomTypeScreen({super.key});

  @override
  State<ChooseRoomTypeScreen> createState() => _ChooseRoomTypeScreenState();
}

class _ChooseRoomTypeScreenState extends State<ChooseRoomTypeScreen> {
  String? selectedType;

  void handleJoin() {
    if (selectedType == null) return;

    if (selectedType == "1v1") {
      Navigator.pushNamed(
        context,
        AppRoutes.selectBackground,
        arguments: "1v1",
      );
    } else if (selectedType == "group") {
      _showJoinGroupDialog();
    } else if (selectedType == "create") {
      Navigator.pushNamed(
        context,
        AppRoutes.selectBackground,
        arguments: "create",
      );
    }
  }

  void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    const Text(
                      'Join a room',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            AppRoutes.selectBackground,
                            arguments: "group",
                          );
                        },
                        child: _dialogOptionCard(
                          'Random Match',
                          'Meet\nsomeone\nnew!',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.joinRoomId);
                        },
                        child: _dialogOptionCard(
                          'Room ID',
                          'Enter a Room\nID to join your\nfriend.',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dialogOptionCard(String title, String subtitle) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomTypeCard({
    required String type,
    required String title,
    required String description,
    required String imagePath,
    double? minHeight,
    double imageHeight = 85,
    double verticalPadding = 16,
  }) {
    final isSelected = selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        constraints: minHeight != null
            ? BoxConstraints(minHeight: minHeight)
            : const BoxConstraints(),
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            width: isSelected ? 4 : 1,
            color: isSelected ? const Color(0xFFF0BFD6) : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.13 : 0.07),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            Image.asset(
              imagePath,
              height: imageHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.groups_rounded,
                size: 48,
                color: Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backBtn(BuildContext context) {
    return Semantics(
      label: 'Go back',
      button: true,
      child: GestureDetector(
        onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
        child: Container(
          width: 52,
          height: 52,
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
          child: SvgPicture.asset(
            'assets/images/icons/Back.svg',
            width: 26,
            height: 26,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSelectedAny = selectedType != null;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
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
                    _backBtn(context),
                    Expanded(
                      child: Text(
                        'Choose your room type',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 52),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                // ── Scrollable cards ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(0xFF85BA72),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'User online ~ 234',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // ── 1v1 / Group — half each ──
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _roomTypeCard(
                                  type: '1v1',
                                  title: '1 on 1',
                                  description:
                                      'A private chat with\none stranger.\nCozy and personal.',
                                  imagePath: 'assets/images/1on1_doodle.png',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _roomTypeCard(
                                  type: 'group',
                                  title: 'Group',
                                  description:
                                      'Meet multiple\nstrangers at once.\nMore fun, more\nchaos!',
                                  imagePath: 'assets/images/group_doodle.png',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── Create Group Room — full width, same as row above ──
                        _roomTypeCard(
                          type: 'create',
                          title: 'Create Group Room',
                          description: 'Chat privately with your crew.',
                          imagePath: 'assets/images/create_group_doodle.png',
                          imageHeight: 120,
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Join Room button pinned to bottom ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 16, 40, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: isSelectedAny ? handleJoin : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD9EACF),
                        disabledBackgroundColor: const Color(0xFFE8E8E8),
                        foregroundColor: Colors.black,
                        disabledForegroundColor: Colors.black38,
                        elevation: isSelectedAny ? 3 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Join Room',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
}
