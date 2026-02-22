import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';

import 'package:final66133505/core/database/database.dart';
import 'package:final66133505/core/di/injection.dart';
import 'package:final66133505/core/theme/app_theme.dart';
import '../../domain/entities/polling_station.dart';

import '../widgets/card_polling_station.dart';

class PollingStationPage extends StatefulWidget {
  const PollingStationPage({super.key});

  @override
  State<PollingStationPage> createState() => _PollingStationPageState();
}

class _PollingStationPageState extends State<PollingStationPage> {

  final PollingStationRepository _stationRepo = sl<PollingStationRepository>();
  List<PollingStation> _stations = [];

  bool _isLoading = true;
  String? _error;
  SyncStatus _syncStatus = const SyncStatus();

  StreamSubscription<SyncStatus>? _syncSub;

  @override
  void initState() {
    super.initState();
    _loadPollingStations();

    // Auto-refresh when background sync completes.
    final syncManager = sl<AutoSyncManager>();
    _syncStatus = syncManager.currentStatus;
    _syncSub = syncManager.statusStream.listen((status) {
      final wasNotSynced = _syncStatus.state != SyncState.synced;
      if (mounted) setState(() => _syncStatus = status);
      if (status.state == SyncState.synced && wasNotSynced && mounted) {
        _loadPollingStations();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPollingStations() async {
     setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _stationRepo.pullFromFirestore();
      final entities = await _stationRepo.getAll();

      final stations = entities.map((e) => PollingStation(
        stationId: e.stationId,
        stationName: e.stationName,
        zone: e.zone,
        province: e.province,
        updatedAt: e.updatedAt,
        isDeleted: e.isDeleted,
        isSynced: e.isSynced,
      )).toList();


      if (mounted) {
        setState(() {
          _stations = stations;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      Logger('PollingStationPage').severe('Failed to load polling stations', e, s);
      if (mounted) {
        setState(() {
          _error = 'Failed to load polling stations';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Column(
        children: [
          _buildSyncBanner(cs),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: cs.primary))
                : _error != null
                    ? Center(
                        child: Text(_error!, style: theme.textTheme.bodyLarge),
                      )
                    : _buildBody(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/polling_stations/add');
        },
        tooltip: 'Add Polling Station',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSyncBanner(ColorScheme cs) {
    if (_syncStatus.state == SyncState.idle && !_syncStatus.hasPending) {
      return const SizedBox.shrink();
    }

    final (Color bg, Color fg, IconData icon, String text) =
        switch (_syncStatus.state) {
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
        'All stations synced ✓',
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
        '${_syncStatus.pendingCount} station${_syncStatus.pendingCount > 1 ? "s" : ""} pending sync',
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
                  'Sync now',
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

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadPollingStations,
      child: ListView.separated(
        padding: const EdgeInsets.all(8.0),
        itemCount: _stations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final station = _stations[index];
          return PollingStationCard(
            station: station,
            onTap: () async {
              final result = await context.push('/polling_stations/detail/${station.stationId}', extra: station);
              if (result == true) {
                _loadPollingStations();
              }
            },
          );
        },
      ),
    );
  }
}