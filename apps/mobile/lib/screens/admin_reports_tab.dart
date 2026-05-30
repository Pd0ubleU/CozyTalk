import 'package:flutter/material.dart';
import 'admin_shared.dart';

// ─── Report Card ───
class AdminReportCard extends StatelessWidget {
  final AdminReport report;
  final VoidCallback onTap;
  const AdminReportCard({super.key, required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminMascotAvatar(size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              report.reported,
                              style: Theme.of(context).textTheme.bodyLarge!
                                  .copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AdminC.ink,
                                  ),
                            ),
                            if (report.outcome != null)
                              _OutcomeBadge(outcome: report.outcome!),
                          ],
                        ),
                      ),
                      Text(
                        report.time,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          fontSize: 11,
                          color: AdminC.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminC.inkSoft,
                      ),
                      children: [
                        const TextSpan(text: 'reported by '),
                        TextSpan(
                          text: report.reporter,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AdminC.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: report.reasons
                        .map(
                          (r) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6EAD0),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              r,
                              style: Theme.of(context).textTheme.labelSmall!
                                  .copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AdminC.brownDarker,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 14,
                        color: AdminC.inkSoft,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        report.room,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          fontSize: 11,
                          color: AdminC.inkSoft,
                        ),
                      ),
                      if (report.evidence > 0) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.image_outlined,
                          size: 14,
                          color: AdminC.inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${report.evidence} attachment${report.evidence > 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.labelSmall!
                              .copyWith(fontSize: 11, color: AdminC.inkSoft),
                        ),
                      ],
                    ],
                  ),
                  if (report.outcome != null) ...[
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'by ',
                            style: TextStyle(
                              fontSize: 11,
                              color: AdminC.inkSoft,
                            ),
                          ),
                          TextSpan(
                            text: report.outcome!.by,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AdminC.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reports Tab ───
class AdminReportsTab extends StatefulWidget {
  final List<AdminReport> reports;
  final void Function(AdminReport) onOpen;
  final String query;
  const AdminReportsTab({
    super.key,
    required this.reports,
    required this.onOpen,
    required this.query,
  });

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  String _reportFilter = 'pending';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.reports.where((r) {
      final matchFilter = _reportFilter == 'all'
          ? true
          : r.status == _reportFilter;
      final q = widget.query.toLowerCase();
      final matchQuery =
          r.reported.toLowerCase().contains(q) ||
          r.reporter.toLowerCase().contains(q) ||
          r.reportedUserId.toLowerCase().contains(q);
      return matchFilter && matchQuery;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 6,
            children:
                [
                  ['pending', 'Pending'],
                  ['resolved', 'Resolved'],
                  ['all', 'All'],
                ].map((e) {
                  final active = _reportFilter == e[0];
                  return GestureDetector(
                    onTap: () => setState(() => _reportFilter = e[0]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: active ? AdminC.brownDarker : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        border: active
                            ? null
                            : Border.all(color: AdminC.border, width: 1.5),
                      ),
                      child: Text(
                        e[1],
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? const Color(0xFFFFF6E2)
                              : AdminC.inkSoft,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
        ...filtered.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AdminReportCard(report: r, onTap: () => widget.onOpen(r)),
          ),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'No reports here. 🌿',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: AdminC.inkSoft,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Outcome badge ───
class _OutcomeBadge extends StatelessWidget {
  final AdminReportOutcome outcome;
  const _OutcomeBadge({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final banned = outcome.kind == 'banned';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: banned ? AdminC.red : AdminC.neutral,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            banned ? Icons.block_rounded : Icons.check_rounded,
            size: 11,
            color: banned ? Colors.white : AdminC.ink,
          ),
          const SizedBox(width: 4),
          Text(
            outcome.label,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: banned ? Colors.white : AdminC.ink,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
    );
  }
}
