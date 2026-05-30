import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../shared/pill_button.dart';

Future<String?> showThoughtBubbleDialog({
  required BuildContext context,
  required String initialText,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _ThoughtBubbleDialog(initialText: initialText),
  );
}

class _ThoughtBubbleDialog extends StatefulWidget {
  final String initialText;

  const _ThoughtBubbleDialog({required this.initialText});

  @override
  State<_ThoughtBubbleDialog> createState() => _ThoughtBubbleDialogState();
}

class _ThoughtBubbleDialogState extends State<_ThoughtBubbleDialog> {
  static const int _maxLength = 25;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _ctrl.text.trim());

  void _cancel() => Navigator.pop(context);

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
                // Title
                const Center(
                  child: Text(
                    'Edit your thought',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Counter
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _ctrl,
                  builder: (_, val, _) => Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${val.text.length}/$_maxLength',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Text field + clear button
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _ctrl,
                  builder: (_, val, _) => Stack(
                    children: [
                      TextField(
                        controller: _ctrl,
                        maxLength: _maxLength,
                        maxLines: 3,
                        autofocus: true,
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type here...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.fromLTRB(
                            14,
                            12,
                            36,
                            12,
                          ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.brownDeep,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      if (val.text.isNotEmpty)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Semantics(
                            label: 'Clear text',
                            button: true,
                            child: GestureDetector(
                              onTap: () => _ctrl.clear(),
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
                ),
                const SizedBox(height: 20),
                // Buttons
                Row(
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
                      label: 'Save',
                      bgColor: AppColors.greenLight,
                      borderColor: const Color(0xFFC7D2B5),
                      textColor: Colors.black87,
                      onTap: _save,
                    ),
                  ],
                ),
              ],
            ),
            // X close
            Positioned(
              top: -10,
              right: -10,
              child: Semantics(
                label: 'Cancel',
                button: true,
                child: GestureDetector(
                  onTap: _cancel,
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
}
