import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:final66133505/core/theme/app_theme.dart';
import '../../domain/entities/incident_report.dart';

class IncidentReportCard extends StatelessWidget {
  final IncidentReport report;
  final VoidCallback? onTap;

  const IncidentReportCard({super.key, required this.report, this.onTap});

  Color get _severityColor => AppTheme.severityColor(report.severity);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Severity indicator bar ──────────────────────────────
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_severityColor, _severityColor.withOpacity(0.6)],
                  ),
                ),
              ),

              // ── Content ─────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: title + severity badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              report.title,
                              style: GoogleFonts.prompt(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SeverityChip(
                            severity: report.severity,
                            color: _severityColor,
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Description
                      Text(
                        report.description,
                        style: GoogleFonts.prompt(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 10),

                      // Info chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _InfoChip(
                            icon: Icons.how_to_vote_outlined,
                            label: report.stationName,
                          ),
                          if (report.aiResult != null &&
                              report.aiResult!.isNotEmpty)
                            _InfoChip(
                              icon: Icons.smart_toy_outlined,
                              label:
                                  '${report.aiResult} ${(report.aiConfidence * 100).toStringAsFixed(0)}%',
                            ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Footer: person + date + sync
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              report.reporterName,
                              style: GoogleFonts.prompt(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatDate(report.date),
                            style: GoogleFonts.prompt(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            report.isSynced
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off_outlined,
                            size: 15,
                            color: report.isSynced
                                ? AppTheme.syncedColor
                                : AppTheme.pendingColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Severity Chip ───────────────────────────────────────────────────────────

class _SeverityChip extends StatelessWidget {
  final String severity;
  final Color color;

  const _SeverityChip({required this.severity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        severity,
        style: GoogleFonts.prompt(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Info Chip ───────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.prompt(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
