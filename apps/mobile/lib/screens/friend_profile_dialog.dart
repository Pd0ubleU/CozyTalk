import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../models/friend.dart';
import '../shared/layered_avatar.dart';
import '../shared/pill_button.dart';

// ─── Public helpers called from FriendsScreen ───────────────────────────────

void showFriendProfileDialog({
  required BuildContext context,
  required Friend friend,
  required void Function(String newNote) onNoteSaved,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) =>
        _FriendProfileDialog(friend: friend, onNoteSaved: onNoteSaved),
  );
}

// ─── Profile popup (view + edit mode) ───────────────────────────────────────

class _FriendProfileDialog extends StatefulWidget {
  final Friend friend;
  final void Function(String) onNoteSaved;

  const _FriendProfileDialog({required this.friend, required this.onNoteSaved});

  @override
  State<_FriendProfileDialog> createState() => _FriendProfileDialogState();
}

class _FriendProfileDialogState extends State<_FriendProfileDialog> {
  static const int _maxNote = 20;
  late final TextEditingController _noteCtrl;
  late final String _originalName;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _originalName = widget.friend.note ?? '';
    _noteCtrl = TextEditingController(text: _originalName);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _startEdit() => setState(() => _editing = true);

  void _cancel() {
    setState(() {
      _noteCtrl.text = _originalName;
      _editing = false;
    });
  }

  void _save() {
    widget.onNoteSaved(_noteCtrl.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar + Username / Note ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 16),
                    Expanded(child: _buildInfoColumn()),
                  ],
                ),
                const SizedBox(height: 20),
                // ── Interest ──
                _buildInterestSection(),
                // ── Edit-mode buttons ──
                if (_editing) ...[
                  const SizedBox(height: 20),
                  _buildEditButtons(),
                ],
              ],
            ),
            // ── X close ──
            Positioned(
              top: -10,
              right: -10,
              child: Semantics(
                label: 'Close',
                button: true,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: SvgPicture.asset(
                      'assets/images/icons/Close.svg',
                      width: 30,
                      height: 30,
                      colorFilter: const ColorFilter.mode(
                        Colors.black,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar ──
  Widget _buildAvatar() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
            child: widget.friend.avatar.isNotEmpty
                ? LayeredAvatar(boxSize: 68)
                : const Icon(Icons.person, color: Colors.grey, size: 50),
          ),
        ),
      ),
    );
  }

  // ── Username + Note fields ──
  Widget _buildInfoColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Username
        Text(
          'Username',
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.friend.username,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(fontSize: 13, color: Colors.black87),
        ),
        const SizedBox(height: 14),
        // Note label row
        Row(
          children: [
            Text(
              'Note',
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 5),
            Semantics(
              label: 'Edit note',
              button: true,
              child: GestureDetector(
                onTap: _startEdit,
                child: SvgPicture.asset(
                  'assets/images/icons/Edit.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    Colors.black87,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            if (_editing) ...[
              const Spacer(),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _noteCtrl,
                builder: (_, val, _) => Text(
                  '${val.text.length}/$_maxNote',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Note value or input
        if (!_editing)
          Text(
            widget.friend.note?.isNotEmpty == true ? widget.friend.note! : '—',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 13,
              color: Colors.black87,
            ),
          )
        else
          SizedBox(
            height: 38,
            child: TextField(
              controller: _noteCtrl,
              maxLength: _maxNote,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              autofocus: true,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(fontSize: 13),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.brownDeep,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Interest section ──
  Widget _buildInterestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interest',
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.friend.interest.isNotEmpty ? widget.friend.interest : '—',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(fontSize: 13, color: Colors.black87),
        ),
      ],
    );
  }

  // ── Cancel / Save buttons ──
  Widget _buildEditButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PillButton(
          label: 'Cancel',
          bgColor: Colors.grey.shade200,
          borderColor: const Color(0xFFB7B4B4),
          textColor: Colors.black87,
          onTap: _cancel,
        ),
        const SizedBox(width: 12),
        PillButton(
          label: 'save',
          bgColor: AppColors.greenLight,
          borderColor: const Color(0xFFC7D2B5),
          textColor: Colors.black87,
          onTap: _save,
        ),
      ],
    );
  }
}
