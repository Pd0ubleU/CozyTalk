import 'package:flutter/material.dart';
import '../shared/layered_avatar.dart';

// ─── Design tokens ───
class AdminC {
  static const brown = Color(0xFF6E5B57);
  static const brownDarker = Color(0xFF3F3230);
  static const cream = Color(0xFFFBF4E5);
  static const creamDeep = Color(0xFFF6EAD0);
  static const green = Color(0xFFD6E8B4);
  static const greenInk = Color(0xFF3F4E1F);
  static const red = Color(0xFFD85542);
  static const redSoft = Color(0xFFF1DDD7);
  static const neutral = Color(0xFFD8D2C8);
  static const ink = Color(0xFF1F1A18);
  static const inkSoft = Color(0xFF6B5F5A);
  static const border = Color(0xFFEDE3CE);
}

// ─── Ban sub-models ───
class AdminBanReportRef {
  final String id;
  final String by;
  final String time;
  const AdminBanReportRef({
    required this.id,
    required this.by,
    required this.time,
  });
}

class AdminBanRecord {
  final String reason;
  final String duration;
  final String date;
  final String by;
  final String note;
  final String? expires;
  const AdminBanRecord({
    required this.reason,
    required this.duration,
    required this.date,
    required this.by,
    this.note = '',
    this.expires,
  });
}

class AdminBanDetailSubject {
  final String name;
  final String uid;
  final bool online;
  final String interest;
  final int reports;
  final String joined;
  final AdminBanRecord? current;
  final List<AdminBanReportRef> reportRefs;
  final List<AdminBanRecord> previous;
  const AdminBanDetailSubject({
    required this.name,
    required this.uid,
    this.online = false,
    this.interest = '',
    this.reports = 0,
    this.joined = '',
    this.current,
    this.reportRefs = const [],
    this.previous = const [],
  });
}

// ─── Report outcome ───
class AdminReportOutcome {
  final String kind; // 'banned' | 'dismissed'
  final String label;
  final String by;
  const AdminReportOutcome({
    required this.kind,
    required this.label,
    required this.by,
  });
}

// ─── Data models ───
class AdminReport {
  final String id;
  String status;
  final String reporter;
  final String reported;
  final List<String> reasons;
  final String context;
  final String time;
  final int evidence;
  final List<String> contextImageUrls;
  final String? chatLogStoragePath;
  final String severity;
  final String room;
  final String roomId;
  final String reportedUserId;
  final String reportedInterest;
  final String reporterId;
  AdminReportOutcome? outcome;

  AdminReport({
    required this.id,
    required this.status,
    required this.reporter,
    required this.reported,
    required this.reasons,
    required this.context,
    required this.time,
    required this.evidence,
    this.contextImageUrls = const [],
    this.chatLogStoragePath,
    required this.severity,
    required this.room,
    required this.roomId,
    required this.reportedUserId,
    required this.reportedInterest,
    this.reporterId = '',
    this.outcome,
  });
}

class AdminUser {
  final String id;
  final String userId;
  final String name;
  final String interest;
  bool online;
  bool banned;
  String room;
  String roomId;
  String session;
  final int reports;
  final String joined;
  final List<AdminBanRecord> banHistory;

  AdminUser({
    required this.id,
    required this.userId,
    required this.name,
    required this.interest,
    required this.online,
    this.banned = false,
    required this.room,
    this.roomId = '—',
    required this.session,
    required this.reports,
    required this.joined,
    List<AdminBanRecord>? banHistory,
  }) : banHistory = banHistory ?? [];
}

class BannedUser {
  final String id;
  final String name;
  final String uid;
  final String reason;
  final String duration;
  final String date;
  final String expires;
  final String by;
  final String note;
  final List<AdminBanReportRef> reportRefs;
  final List<AdminBanRecord> previous;

  final String interest;
  final int reports;
  final String joined;

  BannedUser({
    required this.id,
    required this.name,
    this.uid = '—',
    required this.reason,
    required this.duration,
    required this.date,
    this.expires = '—',
    required this.by,
    this.note = '',
    this.reportRefs = const [],
    this.previous = const [],
    this.interest = '',
    this.reports = 0,
    this.joined = '',
  });

  AdminBanDetailSubject toDetailSubject() => AdminBanDetailSubject(
    name: name,
    uid: uid,
    online: false,
    interest: interest,
    reports: reports,
    joined: joined,
    current: AdminBanRecord(
      reason: reason,
      duration: duration,
      date: date,
      by: by,
      note: note,
      expires: expires,
    ),
    reportRefs: reportRefs,
    previous: previous,
  );
}

const kBanReasons = [
  'Harassment or Bullying',
  'Spam & Scams',
  'Exposing private identifying information',
  'Others',
];

// ─── User avatar (LayeredAvatar) ───
class AdminMascotAvatar extends StatelessWidget {
  final double size;
  final bool? online;
  const AdminMascotAvatar({super.key, this.size = 48, this.online});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: EdgeInsets.only(top: size * 0.1),
              child: Center(child: LayeredAvatar(boxSize: size)),
            ),
          ),
        ),
        if (online != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * .24,
              height: size * .24,
              decoration: BoxDecoration(
                color: online!
                    ? const Color(0xFF5BBE6B)
                    : const Color(0xFFB5ADA4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Admin confirm dialogs ───
void showAdminConfirmDismiss({
  required BuildContext context,
  required String reportedName,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _AdminConfirmDialog(
      title: 'Dismiss report?',
      body: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
          height: 1.5,
        ),
        children: [
          const TextSpan(
            text: 'Are you sure you want to dismiss the\nreport against ',
          ),
          TextSpan(
            text: reportedName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: '?'),
        ],
      ),
      confirmLabel: 'Dismiss',
      confirmBg: AdminC.neutral,
      confirmFg: AdminC.ink,
      confirmBorder: AdminC.border,
      onConfirm: onConfirm,
    ),
  );
}

void showAdminConfirmBan({
  required BuildContext context,
  required String username,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _AdminConfirmDialog(
      title: 'Ban "$username"?',
      body: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'Select a reason and duration\nfor banning '),
          TextSpan(
            text: username,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      confirmLabel: 'Continue',
      confirmBg: AdminC.red,
      confirmFg: Colors.white,
      confirmBorder: const Color(0xFFA33615),
      onConfirm: onConfirm,
    ),
  );
}

void showAdminConfirmUnban({
  required BuildContext context,
  required String username,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _AdminConfirmDialog(
      title: 'Unban "$username"?',
      body: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'Are you sure you want to unban '),
          TextSpan(
            text: username,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: '?\nThey will regain access to CozyTalk.'),
        ],
      ),
      confirmLabel: 'Unban',
      confirmBg: AdminC.green,
      confirmFg: AdminC.greenInk,
      confirmBorder: const Color(0xFFC7D2B5),
      onConfirm: onConfirm,
    ),
  );
}

class _AdminConfirmDialog extends StatelessWidget {
  final String title;
  final InlineSpan body;
  final String confirmLabel;
  final Color confirmBg, confirmFg, confirmBorder;
  final VoidCallback onConfirm;
  const _AdminConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmBg,
    required this.confirmFg,
    required this.confirmBorder,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            RichText(textAlign: TextAlign.center, text: body),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AdminConfirmBtn(
                  label: 'Cancel',
                  bg: Colors.grey.shade200,
                  fg: Colors.black87,
                  border: const Color(0xFFB7B4B4),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                _AdminConfirmBtn(
                  label: confirmLabel,
                  bg: confirmBg,
                  fg: confirmFg,
                  border: confirmBorder,
                  onTap: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminConfirmBtn extends StatelessWidget {
  final String label;
  final Color bg, fg, border;
  final VoidCallback onTap;
  const _AdminConfirmBtn({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ─── Action button ───
class AdminActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final String tone;
  final bool disabled;
  final VoidCallback onTap;
  const AdminActionBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = {
      'neutral': (bg: const Color(0xFFF6EAD0), fg: AdminC.brownDarker),
      'warn': (bg: const Color(0xFFFAE7C8), fg: const Color(0xFF8A5A14)),
      'danger': (bg: AdminC.redSoft, fg: const Color(0xFF9F2A18)),
    }[tone]!;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? .4 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: colors.fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Modal button ───
class AdminModalBtn extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final VoidCallback? onTap;
  final IconData? icon;
  const AdminModalBtn({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Toast ───
class AdminToast extends StatelessWidget {
  final String msg;
  const AdminToast({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AdminC.green,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: AdminC.greenInk,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Ban Modal (2-step) ───
class AdminBanModal extends StatefulWidget {
  final String username;
  final VoidCallback onClose;
  final void Function(String name, String reason, String duration) onConfirm;
  const AdminBanModal({
    super.key,
    required this.username,
    required this.onClose,
    required this.onConfirm,
  });

  @override
  State<AdminBanModal> createState() => _AdminBanModalState();
}

class _AdminBanModalState extends State<AdminBanModal> {
  int _step = 1;
  String? _reason;
  String _other = '';
  String _duration = 'Permanent';
  final _otherCtrl = TextEditingController();

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  String get _finalReason => (_reason == 'Others' && _other.isNotEmpty)
      ? 'Others: $_other'
      : (_reason ?? '');
  bool get _canNext =>
      _reason != null && !(_reason == 'Others' && _other.isEmpty);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: .5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .2),
                  blurRadius: 40,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AdminC.redSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.block_rounded,
                        color: Color(0xFF9F2A18),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ban ${widget.username}',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AdminC.ink,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Icon(
                        Icons.close_rounded,
                        color: AdminC.inkSoft,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _step >= 1 ? AdminC.red : AdminC.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _step >= 2 ? AdminC.red : AdminC.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_step == 1) ..._buildStep1(),
                if (_step == 2) ..._buildStep2(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep1() => [
    Text(
      'Why are you banning this user? Choose one.',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium!.copyWith(fontSize: 13, color: AdminC.inkSoft),
    ),
    const SizedBox(height: 12),
    ...kBanReasons.map((r) {
      final active = _reason == r;
      return GestureDetector(
        onTap: () => setState(() => _reason = r),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? AdminC.green : Colors.white,
            border: Border.all(
              color: active
                  ? AdminC.greenInk.withValues(alpha: .4)
                  : AdminC.border,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: active ? AdminC.greenInk : Colors.white,
                  border: Border.all(
                    color: active ? AdminC.greenInk : AdminC.border,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: active
                    ? const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AdminC.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }),
    if (_reason == 'Others')
      TextField(
        controller: _otherCtrl,
        onChanged: (v) => setState(() => _other = v),
        maxLines: 2,
        decoration: InputDecoration(
          hintText: 'Type the reason…',
          hintStyle: Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(color: AdminC.inkSoft, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AdminC.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AdminC.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AdminC.brownDarker, width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(10),
        ),
        style: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(fontSize: 13, color: AdminC.ink),
      ),
    const SizedBox(height: 14),
    Row(
      children: [
        Expanded(
          child: AdminModalBtn(
            label: 'Cancel',
            bg: AdminC.neutral,
            fg: AdminC.ink,
            onTap: widget.onClose,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AdminModalBtn(
            label: 'Next',
            bg: AdminC.green,
            fg: AdminC.greenInk,
            onTap: _canNext ? () => setState(() => _step = 2) : null,
          ),
        ),
      ],
    ),
  ];

  List<Widget> _buildStep2() => [
    Text(
      'How long should the ban last?',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium!.copyWith(fontSize: 13, color: AdminC.inkSoft),
    ),
    const SizedBox(height: 12),
    GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: ['1 day', '7 days', '30 days', 'Permanent'].map((d) {
        final active = _duration == d;
        return GestureDetector(
          onTap: () => setState(() => _duration = d),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AdminC.brownDarker : Colors.white,
              border: Border.all(
                color: active ? AdminC.brownDarker : AdminC.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              d,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: active ? const Color(0xFFFFF6E2) : AdminC.ink,
              ),
            ),
          ),
        );
      }).toList(),
    ),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EAD0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFF8A5A14),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AdminC.ink,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: widget.username,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: ' will be banned for '),
                  TextSpan(
                    text: _duration.toLowerCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: ' for '),
                  TextSpan(
                    text: _finalReason,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(
                    text:
                        '. They will be removed from their current room immediately.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    Row(
      children: [
        Expanded(
          child: AdminModalBtn(
            label: 'Back',
            bg: AdminC.neutral,
            fg: AdminC.ink,
            onTap: () => setState(() => _step = 1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AdminModalBtn(
            label: 'Confirm Ban',
            bg: AdminC.red,
            fg: Colors.white,
            icon: Icons.block_rounded,
            onTap: () =>
                widget.onConfirm(widget.username, _finalReason, _duration),
          ),
        ),
      ],
    ),
  ];
}
