import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';

import 'package:final66133505/core/database/database.dart';
import 'package:final66133505/core/di/injection.dart';
import 'package:final66133505/core/theme/app_theme.dart';
import '../../domain/entities/incident_report.dart';
import '../widgets/incident_report_card.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final IncidentReportRepository _reportRepo = sl<IncidentReportRepository>();
  final PollingStationRepository _stationRepo = sl<PollingStationRepository>();
  final ViolationTypeRepository _typeRepo = sl<ViolationTypeRepository>();

  static final _log = Logger('ReportPage');

  List<IncidentReport> _reports = [];
  bool _isLoading = true;
  String? _error;
  SyncStatus _syncStatus = const SyncStatus();

  StreamSubscription<SyncStatus>? _syncSub;

  @override
  void initState() {
    super.initState();
    _loadReports();

    // Auto-refresh when background sync completes.
    final syncManager = sl<AutoSyncManager>();
    _syncStatus = syncManager.currentStatus;
    _syncSub = syncManager.statusStream.listen((status) {
      final wasNotSynced = _syncStatus.state != SyncState.synced;
      if (mounted) setState(() => _syncStatus = status);
      if (status.state == SyncState.synced && wasNotSynced && mounted) {
        _loadReports();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _reportRepo.pullFromFirestore();

      final entities = await _reportRepo.getAll();
      final stations = await _stationRepo.getAll();
      final types = await _typeRepo.getAll();

      final stationMap = {for (final s in stations) s.stationId: s};
      final typeMap = {for (final t in types) t.typeId: t};

      final reports = entities.map((e) {
        final station = stationMap[e.stationId];
        final type = typeMap[e.typeId];

        return IncidentReport(
          id: e.reportId ?? 0,
          description: e.description,
          date: DateTime.tryParse(e.timestamp) ?? DateTime.now(),
          reporterName: e.reporterName,
          stationId: e.stationId,
          stationName: station?.stationName ?? 'Station #${e.stationId}',
          zone: station?.zone ?? '-',
          province: station?.province ?? '-',
          typeId: e.typeId,
          violationTypeName: type?.typeName ?? 'Type #${e.typeId}',
          severity: type?.severity ?? 'Low',
          aiResult: e.aiResult,
          aiConfidence: e.aiConfidence,
          evidencePhoto: e.evidencePhoto,
          isSynced: e.isSynced,
        );
      }).toList();

      _log.info('Loaded ${reports.length} reports');

      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e, s) {
      _log.severe('Failed to load reports', e, s);
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // ── Sync status banner ──────────────────────────────────────
          _buildSyncBanner(colorScheme),

          // ── Body ────────────────────────────────────────────────────
          Expanded(child: _buildBody(theme, colorScheme)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/reports/add');
          if (result == true) _loadReports();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'New Report',
          style: GoogleFonts.prompt(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSyncBanner(ColorScheme colorScheme) {
    // Only show when there's something interesting to report.
    if (_syncStatus.state == SyncState.idle && !_syncStatus.hasPending) {
      return const SizedBox.shrink();
    }

    final (
      Color bg,
      Color fg,
      IconData icon,
      String text,
    ) = switch (_syncStatus.state) {
      SyncState.syncing => (
        const Color(0xFFE3F2FD),
        const Color(0xFF0D47A1),
        Icons.sync_rounded,
        'Syncing with server…',
      ),
      SyncState.synced => (
        AppTheme.syncedColor.withOpacity(0.1),
        AppTheme.syncedColor,
        Icons.cloud_done_rounded,
        'All reports synced ✓',
      ),
      SyncState.offline => (
        AppTheme.offlineColor.withOpacity(0.1),
        AppTheme.offlineColor,
        Icons.cloud_off_rounded,
        'Offline — changes saved locally',
      ),
      SyncState.error => (
        AppTheme.severityHigh.withOpacity(0.1),
        AppTheme.severityHigh,
        Icons.sync_problem_rounded,
        'Sync failed — tap to retry',
      ),
      SyncState.idle when _syncStatus.hasPending => (
        AppTheme.pendingColor.withOpacity(0.1),
        AppTheme.pendingColor,
        Icons.cloud_upload_outlined,
        '${_syncStatus.pendingCount} report${_syncStatus.pendingCount > 1 ? "s" : ""} pending sync',
      ),
      _ => (Colors.transparent, Colors.transparent, Icons.sync, ''),
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return Material(
      color: bg,
      child: InkWell(
        onTap: () => sl<AutoSyncManager>().requestSync(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              if (_syncStatus.isSyncing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                Icon(icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.prompt(
                    color: fg,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              if (_syncStatus.hasPending && !_syncStatus.isSyncing)
                Text(
                  'Sync',
                  style: GoogleFonts.prompt(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppTheme.severityHigh, size: 56),
              const SizedBox(height: 16),
              Text(
                'Failed to load reports',
                style: GoogleFonts.prompt(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.prompt(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadReports,
                icon: const Icon(Icons.refresh),
                label: Text('Retry', style: GoogleFonts.prompt()),
              ),
            ],
          ),
        ),
      );
    }

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.how_to_vote_outlined,
              size: 72,
              color: colorScheme.primary.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No incident reports',
              style: GoogleFonts.prompt(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first report',
              style: GoogleFonts.prompt(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadReports,
              icon: const Icon(Icons.refresh),
              label: Text('Refresh', style: GoogleFonts.prompt()),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 88, left: 4, right: 4),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          return IncidentReportCard(
            report: report,
            onTap: () async {
              final result = await context.push('/reports/detail/${report.id}');
              if (result == true) _loadReports();
            },
          );
        },
      ),
    );
  }
}
