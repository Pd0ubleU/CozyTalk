import 'package:flutter/material.dart';
import 'admin_shared.dart';

// Design tokens (same palette)
class _C {
  static const brown      = Color(0xFF6E5B57);
  static const brownDarker= Color(0xFF3F3230);
  static const cream      = Color(0xFFFBF4E5);
  static const green      = Color(0xFFD6E8B4);
  static const greenInk   = Color(0xFF3F4E1F);
  static const red        = Color(0xFFD85542);
  static const redSoft    = Color(0xFFF1DDD7);
  static const neutral    = Color(0xFFD8D2C8);
  static const ink        = Color(0xFF1F1A18);
  static const inkSoft    = Color(0xFF6B5F5A);
  static const border     = Color(0xFFEDE3CE);
}

class AdminReportDetailScreen extends StatefulWidget {
  final AdminReport report;
  final VoidCallback onDismiss;
  final VoidCallback onBanRequested;

  const AdminReportDetailScreen({
    super.key,
    required this.report,
    required this.onDismiss,
    required this.onBanRequested,
  });

  @override
  State<AdminReportDetailScreen> createState() => _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  bool _showBanModal = false;
  String? _banReason;
  String _banOther = '';
  String _banDuration = 'Permanent';
  int _banStep = 1;
  final _otherCtrl = TextEditingController();

  @override
  void dispose() { _otherCtrl.dispose(); super.dispose(); }

  String get _finalReason => (_banReason == 'Others' && _banOther.isNotEmpty)
      ? 'Others: $_banOther' : (_banReason ?? '');
  bool get _canNext => _banReason != null && !(_banReason == 'Others' && _banOther.isEmpty);

  void _dismiss() {
    widget.onDismiss();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.cream,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                  children: [
                    _buildReportedUserCard(),
                    const SizedBox(height: 12),
                    _buildSection('Reasons reported', _buildReasons()),
                    const SizedBox(height: 12),
                    _buildSection(
                      'Additional context',
                      _buildContext(),
                      sub: 'from ${widget.report.reporter} · ${widget.report.time}',
                    ),
                    if (widget.report.evidence > 0) ...[
                      const SizedBox(height: 12),
                      _buildSection('Attached images (${widget.report.evidence})', _buildEvidence()),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Sticky footer
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildFooter(context),
          ),
          if (_showBanModal)
            _buildBanOverlay(),
        ],
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _C.brown,
      padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 22, 18, 28),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 4, offset: const Offset(0,2))],
              ),
              child: const Icon(Icons.chevron_left_rounded, color: _C.brownDarker, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Report Detail', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('#${widget.report.id.toUpperCase()} · ${widget.report.time}',
                style: const TextStyle(fontSize: 12, color: Color(0xBFFFFFFF))),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Reported user card ───
  Widget _buildReportedUserCard() {
    final r = widget.report;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0,4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: const Color(0xFFFAE3C9), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.person, color: _C.brownDarker, size: 36),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('REPORTED USER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.inkSoft, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(r.reported, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink)),
                    const SizedBox(height: 6),
                    Text('seen in ${r.room} · ${r.roomId}', style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF6EAD0), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(child: _MiniStat(label: 'Prior reports', value: '3')),
                Container(width: 1, height: 30, color: _C.border),
                Expanded(child: _MiniStat(label: 'Account age', value: '1m')),
                Container(width: 1, height: 30, color: _C.border),
                Expanded(child: _MiniStat(label: 'Status', value: 'Active', valueColor: const Color(0xFF3B7A2A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reasons ───
  Widget _buildReasons() {
    return Column(
      children: widget.report.reasons.map((reason) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _C.redSoft, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.flag_rounded, color: Color(0xFF9F2A18), size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(reason, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF9F2A18)))),
        ]),
      )).toList(),
    );
  }

  // ─── Context quote ───
  Widget _buildContext() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF6EAD0), borderRadius: BorderRadius.circular(12)),
      child: Text('"${widget.report.context}"',
        style: const TextStyle(fontSize: 13, color: _C.ink, height: 1.5)),
    );
  }

  // ─── Evidence placeholders ───
  Widget _buildEvidence() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.report.evidence,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Container(
          width: 110,
          decoration: BoxDecoration(
            color: const Color(0xFFF6EAD0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border, width: 1.5),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 7, width: double.infinity * .7, decoration: BoxDecoration(color: const Color(0xFFEDE3CE), borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 4),
              Container(height: 7, color: _C.redSoft, margin: const EdgeInsets.only(right: 10)),
              const SizedBox(height: 4),
              Container(height: 7, width: double.infinity * .4, decoration: BoxDecoration(color: const Color(0xFFEDE3CE), borderRadius: BorderRadius.circular(4))),
              const Spacer(),
              Container(height: 7, color: _C.redSoft, margin: const EdgeInsets.only(left: 20)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section wrapper ───
  Widget _buildSection(String title, Widget child, {String? sub}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _C.ink)),
              if (sub != null) Text(sub, style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
            ],
          ),
        ),
        child,
      ],
    );
  }

  // ─── Sticky footer ───
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [const Color(0xFFFBF4E5), const Color(0xFFFBF4E5).withValues(alpha: 0)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: _C.neutral, borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 4, offset: const Offset(0,3))]),
                child: const Center(child: Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _C.ink))),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() { _showBanModal = true; _banStep = 1; _banReason = null; }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _C.red,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(color: const Color(0xFF962B14).withValues(alpha: .3), blurRadius: 8, offset: const Offset(0,3))],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Ban user', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Ban overlay (2-step, embedded) ───
  Widget _buildBanOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: .5),
      child: Center(
        child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .2), blurRadius: 40, offset: const Offset(0,22))],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: _C.redSoft, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.block_rounded, color: Color(0xFF9F2A18), size: 18)),
                const SizedBox(width: 8),
                Expanded(child: Text('Ban ${widget.report.reported}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _C.ink))),
                GestureDetector(
                  onTap: () => setState(() => _showBanModal = false),
                  child: const Icon(Icons.close_rounded, color: _C.inkSoft, size: 22)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Container(height: 4, decoration: BoxDecoration(
                  color: _banStep >= 1 ? _C.red : _C.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(width: 6),
                Expanded(child: Container(height: 4, decoration: BoxDecoration(
                  color: _banStep >= 2 ? _C.red : _C.border, borderRadius: BorderRadius.circular(2)))),
              ]),
              const SizedBox(height: 14),
              if (_banStep == 1) ..._buildBanStep1(),
              if (_banStep == 2) ..._buildBanStep2(),
            ],
          ),
        ),
        ),
      ),
    );
  }

  List<Widget> _buildBanStep1() => [
    const Text('Why are you banning this user? Choose one.',
      style: TextStyle(fontSize: 13, color: _C.inkSoft)),
    const SizedBox(height: 12),
    ...const ['Harassment or Bullying', 'Spam & Scams', 'Exposing private identifying information', 'Others']
        .map((r) {
      final active = _banReason == r;
      return GestureDetector(
        onTap: () => setState(() => _banReason = r),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? _C.green : Colors.white,
            border: Border.all(color: active ? _C.greenInk.withValues(alpha: .4) : _C.border, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: active ? _C.greenInk : Colors.white,
                border: Border.all(color: active ? _C.greenInk : _C.border, width: 1.5),
                borderRadius: BorderRadius.circular(5),
              ),
              child: active ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(r, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: _C.ink))),
          ]),
        ),
      );
    }),
    if (_banReason == 'Others')
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: _otherCtrl,
          onChanged: (v) => setState(() => _banOther = v),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Type the reason…',
            hintStyle: const TextStyle(color: _C.inkSoft, fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.border, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.brownDarker, width: 1.5)),
            contentPadding: const EdgeInsets.all(10),
          ),
          style: const TextStyle(fontSize: 13, color: _C.ink),
        ),
      ),
    Row(children: [
      Expanded(child: _ModalBtn(label: 'Cancel', bg: _C.neutral, fg: _C.ink, onTap: () => setState(() => _showBanModal = false))),
      const SizedBox(width: 10),
      Expanded(child: _ModalBtn(label: 'Next', bg: _C.green, fg: _C.greenInk, onTap: _canNext ? () => setState(() => _banStep = 2) : null)),
    ]),
  ];

  List<Widget> _buildBanStep2() => [
    const Text('How long should the ban last?',
      style: TextStyle(fontSize: 13, color: _C.inkSoft)),
    const SizedBox(height: 12),
    GridView.count(
      crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.5,
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      children: ['1 day', '7 days', '30 days', 'Permanent'].map((d) {
        final active = _banDuration == d;
        return GestureDetector(
          onTap: () => setState(() => _banDuration = d),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? _C.brownDarker : Colors.white,
              border: Border.all(color: active ? _C.brownDarker : _C.border, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(d, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
              color: active ? const Color(0xFFFFF6E2) : _C.ink)),
          ),
        );
      }).toList(),
    ),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF6EAD0), borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFF8A5A14), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text.rich(TextSpan(
          style: const TextStyle(fontSize: 12.5, color: _C.ink, height: 1.5),
          children: [
            TextSpan(text: widget.report.reported, style: const TextStyle(fontWeight: FontWeight.w800)),
            const TextSpan(text: ' will be banned for '),
            TextSpan(text: _banDuration.toLowerCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
            const TextSpan(text: ' for '),
            TextSpan(text: _finalReason, style: const TextStyle(fontWeight: FontWeight.w800)),
            const TextSpan(text: '. They will be removed immediately.'),
          ],
        ))),
      ]),
    ),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: _ModalBtn(label: 'Back', bg: _C.neutral, fg: _C.ink, onTap: () => setState(() => _banStep = 1))),
      const SizedBox(width: 10),
      Expanded(child: _ModalBtn(
        label: 'Confirm Ban', bg: _C.red, fg: Colors.white,
        icon: Icons.block_rounded,
        onTap: () {
          widget.onBanRequested();
          setState(() => _showBanModal = false);
          Navigator.pop(context);
        },
      )),
    ]),
  ];
}


// ─── Mini stat ───
class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _MiniStat({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: valueColor ?? _C.ink)),
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _C.inkSoft)),
    ]);
  }
}

// ─── Modal button ───
class _ModalBtn extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final VoidCallback? onTap;
  final IconData? icon;
  const _ModalBtn({required this.label, required this.bg, required this.fg, this.onTap, this.icon});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}
