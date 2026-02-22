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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: cs.primary))
            : _error != null
              ? Center(child: Text(_error!, style: theme.textTheme.bodyLarge))
              : _buildBody(),

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