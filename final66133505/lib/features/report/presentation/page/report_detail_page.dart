import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';

import 'package:final66133505/core/database/database.dart';
import 'package:final66133505/core/di/injection.dart';
import 'package:final66133505/core/theme/app_theme.dart';
import 'package:final66133505/core/utils/image_storage.dart';

class ReportDetailPage extends StatefulWidget {
  final int reportId;

  const ReportDetailPage({super.key, required this.reportId});

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  static final _log = Logger('ReportDetailPage');

  final IncidentReportRepository _reportRepo = sl<IncidentReportRepository>();
  final PollingStationRepository _stationRepo = sl<PollingStationRepository>();
  final ViolationTypeRepository _typeRepo = sl<ViolationTypeRepository>();

  IncidentReportEntity? _report;
  PollingStationEntity? _station;
  ViolationTypeEntity? _violationType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final report = await _reportRepo.getById(widget.reportId);
      PollingStationEntity? station;
      ViolationTypeEntity? violationType;

      if (report != null) {
        station = await _stationRepo.getById(report.stationId);
        violationType = await _typeRepo.getById(report.typeId);
      }

      setState(() {
        _report = report;
        _station = station;
        _violationType = violationType;
        _isLoading = false;
      });
    } catch (e, s) {
      _log.severe('Failed to load report detail', e, s);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 36),
        title: const Text('Delete Report'),
        content: const Text(
          'Are you sure you want to delete this incident report? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _reportRepo.delete(widget.reportId);

        // Push deletion to Firestore and notify dashboard.
        sl<AutoSyncManager>().requestSync();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Report deleted ✓')));
          context.pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }
  }

  Color get _severityColor {
    final sev = _violationType?.severity ?? '';
    return AppTheme.severityColor(sev);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Report #${widget.reportId}',
          style: GoogleFonts.prompt(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final updated = await context.push(
                '/reports/edit/${widget.reportId}',
              );
              if (updated == true && mounted) _load();
            },
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit report',
          ),
          IconButton(
            onPressed: _deleteReport,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete report',
            color: AppTheme.severityHigh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
          ? _buildNotFound(theme)
          : _buildDetail(theme, colorScheme),
    );
  }

  Widget _buildNotFound(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Report not found',
            style: GoogleFonts.prompt(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(ThemeData theme, ColorScheme colorScheme) {
    final report = _report!;
    final date = DateTime.tryParse(report.timestamp) ?? DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sync Banner ──────────────────────────────────────────────
          _SyncBanner(isSynced: report.isSynced),

          const SizedBox(height: 20),

          // ── Incident Info ────────────────────────────────────────────
          _SectionCard(
            icon: Icons.article_outlined,
            title: 'Incident Details',
            colorScheme: colorScheme,
            children: [
              _DetailRow('Report ID', '#${report.reportId}', icon: Icons.tag),
              _DetailRow(
                'Reporter',
                report.reporterName,
                icon: Icons.person_outline,
              ),
              _DetailRow(
                'Date & Time',
                DateFormat('dd MMMM yyyy, HH:mm').format(date),
                icon: Icons.schedule,
              ),
              const Divider(height: 20),
              Text(
                'Description',
                style: GoogleFonts.prompt(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                report.description,
                style: GoogleFonts.prompt(fontSize: 14, height: 1.5),
              ),
              if (report.evidencePhoto != null) ...[
                const SizedBox(height: 12),
                _EvidenceImage(path: report.evidencePhoto!),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // ── AI Analysis ──────────────────────────────────────────────
          _SectionCard(
            icon: Icons.smart_toy_outlined,
            title: 'AI Analysis',
            colorScheme: colorScheme,
            children: [
              _DetailRow(
                'Prediction',
                report.aiResult ?? 'N/A',
                icon: Icons.analytics_outlined,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confidence',
                          style: GoogleFonts.prompt(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: report.aiConfidence,
                            minHeight: 10,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            color: report.aiConfidence >= 0.8
                                ? AppTheme.severityLow
                                : report.aiConfidence >= 0.5
                                ? AppTheme.severityMedium
                                : AppTheme.severityHigh,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    report.aiConfidence > 0
                        ? '${(report.aiConfidence * 100).toStringAsFixed(1)}%'
                        : 'N/A',
                    style: GoogleFonts.prompt(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: report.aiConfidence >= 0.8
                          ? AppTheme.severityLow
                          : report.aiConfidence >= 0.5
                          ? AppTheme.severityMedium
                          : AppTheme.severityHigh,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Station + Violation side by side ─────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SectionCard(
                  icon: Icons.how_to_vote_outlined,
                  title: 'Station',
                  colorScheme: colorScheme,
                  children: _station != null
                      ? [
                          Text(
                            _station!.stationName,
                            style: GoogleFonts.prompt(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_station!.zone}\n${_station!.province}',
                            style: GoogleFonts.prompt(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ]
                      : [Text('Station #${report.stationId}')],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SectionCard(
                  icon: Icons.gavel_outlined,
                  title: 'Violation',
                  colorScheme: colorScheme,
                  children: _violationType != null
                      ? [
                          Text(
                            _violationType!.typeName,
                            style: GoogleFonts.prompt(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _severityColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _severityColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _violationType!.severity,
                              style: GoogleFonts.prompt(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _severityColor,
                              ),
                            ),
                          ),
                        ]
                      : [Text('Type #${report.typeId}')],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Action Buttons ───────────────────────────────────────────
          Row(
            children: [
              // Delete — left-aligned, destructive
              OutlinedButton.icon(
                onPressed: _deleteReport,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text('Delete', style: GoogleFonts.prompt()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.severityHigh,
                  side: BorderSide(
                    color: AppTheme.severityHigh.withOpacity(0.6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(width: 12),
              const Spacer(),
              const SizedBox(width: 12),

              // Edit — right-aligned, primary CTA
              FilledButton.icon(
                onPressed: () async {
                  final updated = await context.push(
                    '/reports/edit/${widget.reportId}',
                  );
                  if (updated == true && mounted) _load();
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                  'Edit Report',
                  style: GoogleFonts.prompt(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Sync Banner ─────────────────────────────────────────────────────────────

class _SyncBanner extends StatelessWidget {
  final bool isSynced;
  const _SyncBanner({required this.isSynced});

  @override
  Widget build(BuildContext context) {
    final color = isSynced ? AppTheme.syncedColor : AppTheme.pendingColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSynced
                  ? 'Synced to Firebase'
                  : 'Pending sync — will upload when online',
              style: GoogleFonts.prompt(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Card ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final ColorScheme colorScheme;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.colorScheme,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.prompt(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ─── Detail Row ──────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const _DetailRow(this.label, this.value, {this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.prompt(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.prompt(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Evidence Image ───────────────────────────────────────────────────────────

class _EvidenceImage extends StatelessWidget {
  final String path;
  const _EvidenceImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fileExists = ImageStorage.exists(path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image_outlined, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Evidence Photo',
              style: GoogleFonts.prompt(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: fileExists
              ? Image.file(
                  File(path),
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(cs),
                )
              : _placeholder(cs),
        ),
      ],
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 40, color: cs.outlineVariant),
          const SizedBox(height: 8),
          Text(
            'Image not available',
            style: GoogleFonts.prompt(fontSize: 12, color: cs.outlineVariant),
          ),
        ],
      ),
    );
  }
}
