import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../constants/db_constants.dart';
import '../database/app_database.dart';
import '../database/local_datasource.dart';
import '../database/remote_datasource.dart';
import '../database/sync_service.dart';
import '../network/network_info.dart';
import '../services/auto_sync_manager.dart';

/// Global service locator instance.
final sl = GetIt.instance;

final _log = Logger('Injection');

/// Registers every dependency in the correct order.
///
/// Must be called once before `runApp`.
Future<void> configureDependencies() async {
  _log.info('Configuring dependencies…');

  // ── Core infrastructure ──────────────────────────────────────────────
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase.instance);
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfo());

  // ── Data sources ─────────────────────────────────────────────────────
  sl.registerLazySingleton<LocalDataSource>(
    () => LocalDataSource(appDatabase: sl<AppDatabase>()),
  );
  sl.registerLazySingleton<RemoteDataSource>(() => RemoteDataSource());

  // ── Repositories ─────────────────────────────────────────────────────
  sl.registerLazySingleton<PollingStationRepository>(
    () => PollingStationRepository(
      localDataSource: sl<LocalDataSource>(),
      remoteDataSource: sl<RemoteDataSource>(),
    ),
  );
  sl.registerLazySingleton<ViolationTypeRepository>(
    () => ViolationTypeRepository(
      localDataSource: sl<LocalDataSource>(),
      remoteDataSource: sl<RemoteDataSource>(),
    ),
  );
  sl.registerLazySingleton<IncidentReportRepository>(
    () => IncidentReportRepository(
      localDataSource: sl<LocalDataSource>(),
      remoteDataSource: sl<RemoteDataSource>(),
    ),
  );

  // ── Sync service ─────────────────────────────────────────────────────
  sl.registerLazySingleton<SyncService>(
    () => SyncService(
      localDataSource: sl<LocalDataSource>(),
      remoteDataSource: sl<RemoteDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  // ── Auto-sync manager ──────────────────────────────────────────────────
  sl.registerLazySingleton<AutoSyncManager>(
    () => AutoSyncManager(
      syncService: sl<SyncService>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  _log.info('Dependencies configured ✓');
}

// ═══════════════════════════════════════════════════════════════════════════════
// Repositories
//
// Each repository sits between the domain / UI layer and the data sources.
// It orchestrates SQLite + Firestore without leaking implementation details.
// ═══════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// PollingStationRepository (pull-only master data)
// ─────────────────────────────────────────────────────────────────────────────

class PollingStationRepository {
  PollingStationRepository({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  final LocalDataSource localDataSource;
  final RemoteDataSource remoteDataSource;
  static final _log = Logger('PollingStationRepository');

  /// Returns all non-deleted polling stations from local DB.
  Future<List<PollingStationEntity>> getAll() async {
    return localDataSource.getAllStations();
  }

  /// Returns a single station by ID from local DB.
  Future<PollingStationEntity?> getById(int id) async {
    return localDataSource.getStationById(id);
  }

  /// Creates a new polling station locally AND syncs it to Firestore.
  /// If [stationId] is provided the record will use that exact ID.
  Future<PollingStationEntity> create({
    required String name,
    required String zone,
    required String province,
    int? stationId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    int newId;
    if (stationId != null && stationId > 0) {
      // Caller supplied an explicit ID — upsert so it is preserved.
      final entity = PollingStationEntity(
        stationId: stationId,
        stationName: name.trim(),
        zone: zone.trim(),
        province: province.trim(),
        updatedAt: now,
        isSynced: false,
      );
      await localDataSource.upsertStation(entity);
      newId = stationId;
    } else {
      // Auto-assign ID via SQLite autoincrement.
      final tmp = PollingStationEntity(
        stationId: 0,
        stationName: name.trim(),
        zone: zone.trim(),
        province: province.trim(),
        updatedAt: now,
        isSynced: false,
      );
      newId = await localDataSource.insertNewStation(tmp);
    }

    final created = PollingStationEntity(
      stationId: newId,
      stationName: name.trim(),
      zone: zone.trim(),
      province: province.trim(),
      updatedAt: now,
      isSynced: true,
    );
    _log.info('Created station id=$newId name=${name.trim()}');

    // Push to Firestore immediately (best-effort)
    try {
      await remoteDataSource.pushStations([created]);
      _log.info('Station id=$newId synced to Firestore');
    } catch (e) {
      _log.warning('Station id=$newId Firestore sync failed (will retry): $e');
      // Mark as unsynced so AutoSyncManager picks it up later
      await localDataSource.upsertStation(
        PollingStationEntity(
          stationId: newId,
          stationName: created.stationName,
          zone: created.zone,
          province: created.province,
          updatedAt: now,
          isSynced: false,
        ),
      );
    }
    return created;
  }

  /// Pulls all polling stations from Firestore → SQLite.
  Future<void> pullFromFirestore() async {
    try {
      final remote = await remoteDataSource.fetchAllStations();
      if (remote.isNotEmpty) {
        await localDataSource.upsertStations(remote);
        _log.info('pullFromFirestore → ${remote.length} stations');
      }
    } catch (e, s) {
      _log.warning('pullFromFirestore failed', e, s);
    }
  }

  /// Pushes all local stations to Firestore (initial seed).
  Future<void> pushAllToFirestore() async {
    try {
      final local = await localDataSource.getAllStations();
      if (local.isNotEmpty) {
        await remoteDataSource.pushStations(local);
        _log.info('pushAllToFirestore → ${local.length} stations');
      }
    } catch (e, s) {
      _log.warning('pushAllToFirestore failed', e, s);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ViolationTypeRepository (pull-only master data)
// ─────────────────────────────────────────────────────────────────────────────

class ViolationTypeRepository {
  ViolationTypeRepository({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  final LocalDataSource localDataSource;
  final RemoteDataSource remoteDataSource;
  static final _log = Logger('ViolationTypeRepository');

  /// Returns all non-deleted violation types from local DB.
  Future<List<ViolationTypeEntity>> getAll() async {
    return localDataSource.getAllTypes();
  }

  /// Returns a single type by ID from local DB.
  Future<ViolationTypeEntity?> getById(int id) async {
    return localDataSource.getTypeById(id);
  }

  /// Creates a new violation type locally AND syncs it to Firestore.
  Future<ViolationTypeEntity> create({
    required String name,
    required String severity,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tmp = ViolationTypeEntity(
      typeId: 0,
      typeName: name.trim(),
      severity: severity,
      updatedAt: now,
      isSynced: false,
    );
    final newId = await localDataSource.insertNewType(tmp);
    final created = ViolationTypeEntity(
      typeId: newId,
      typeName: tmp.typeName,
      severity: tmp.severity,
      updatedAt: now,
      isSynced: true,
    );
    _log.info('Created type id=$newId name=${tmp.typeName}');

    // Push to Firestore immediately (best-effort)
    try {
      await remoteDataSource.pushTypes([created]);
      _log.info('Type id=$newId synced to Firestore');
    } catch (e) {
      _log.warning('Type id=$newId Firestore sync failed (will retry): $e');
    }
    return created;
  }

  /// Pulls all violation types from Firestore → SQLite.
  Future<void> pullFromFirestore() async {
    try {
      final remote = await remoteDataSource.fetchAllTypes();
      if (remote.isNotEmpty) {
        await localDataSource.upsertTypes(remote);
        _log.info('pullFromFirestore → ${remote.length} types');
      }
    } catch (e, s) {
      _log.warning('pullFromFirestore failed', e, s);
    }
  }

  /// Pushes all local types to Firestore (initial seed).
  Future<void> pushAllToFirestore() async {
    try {
      final local = await localDataSource.getAllTypes();
      if (local.isNotEmpty) {
        await remoteDataSource.pushTypes(local);
        _log.info('pushAllToFirestore → ${local.length} types');
      }
    } catch (e, s) {
      _log.warning('pushAllToFirestore failed', e, s);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IncidentReportRepository (bidirectional sync)
// ─────────────────────────────────────────────────────────────────────────────

class IncidentReportRepository {
  IncidentReportRepository({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  final LocalDataSource localDataSource;
  final RemoteDataSource remoteDataSource;
  static final _log = Logger('IncidentReportRepository');

  /// Returns all non-deleted reports from local DB.
  Future<List<IncidentReportEntity>> getAll() async {
    return localDataSource.getAllReports();
  }

  /// Returns a single report by its integer ID.
  Future<IncidentReportEntity?> getById(int id) async {
    return localDataSource.getReportById(id);
  }

  /// Creates a new incident report. SQLite auto-assigns the report_id.
  Future<void> create(IncidentReportEntity entity) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final deviceId = _generateDeviceId();

    final report = entity.copyWith(
      updatedAt: now,
      status: DbConstants.statusPending,
      userId: entity.userId.isEmpty ? 'anonymous' : null,
      deviceId: entity.deviceId.isEmpty ? deviceId : null,
    );

    final newId = await localDataSource.insertReport(report);
    _log.info('Created report id=$newId');
  }

  /// Deletes a report from both SQLite and Firestore.
  Future<void> delete(int id) async {
    // 1. Remove from SQLite immediately (hard delete)
    await localDataSource.hardDeleteReport(id);
    _log.info('Hard-deleted report $id from SQLite');

    // 2. Best-effort remove from Firestore
    try {
      await remoteDataSource.deleteRemoteReport(id);
      _log.info('Deleted report $id from Firestore');
    } catch (e) {
      // Not fatal — Firestore delete will be retried via sync
      _log.warning('Could not delete report $id from Firestore: $e');
    }
  }

  /// Updates an existing report, marking it pending sync again.
  Future<void> update(IncidentReportEntity entity) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = entity.copyWith(
      updatedAt: now,
      status: DbConstants.statusPending,
    );
    await localDataSource.updateReport(updated);
    _log.info('Updated report id=${entity.reportId}');
  }

  /// Returns the count of reports not yet synced.
  Future<int> getUnsyncedCount() async {
    return localDataSource.getUnsyncedReportCount();
  }

  /// Pushes all unsynced reports to Firestore.
  Future<void> syncUnsynced() async {
    try {
      final pending = await localDataSource.getPendingReports();
      if (pending.isNotEmpty) {
        await remoteDataSource.uploadReports(pending);
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final r in pending) {
          if (r.reportId != null) {
            await localDataSource.markAsSynced(r.reportId!, now);
          }
        }
        _log.info('syncUnsynced → ${pending.length} reports pushed');
      }
    } catch (e, s) {
      _log.warning('syncUnsynced failed', e, s);
    }
  }

  /// Pushes ALL local reports (regardless of sync status) to Firestore.
  ///
  /// Used for the initial seed push so that even `synced`-marked seed rows
  /// are uploaded on first run.
  Future<void> pushAllToFirestore() async {
    try {
      final all = await localDataSource.getAllReports();
      if (all.isEmpty) return;
      await remoteDataSource.uploadReports(all);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final r in all) {
        if (r.reportId != null) {
          await localDataSource.markAsSynced(r.reportId!, now);
        }
      }
      _log.info('pushAllToFirestore → ${all.length} reports pushed');
    } catch (e, s) {
      _log.warning('pushAllToFirestore failed', e, s);
    }
  }

  /// Pulls all reports from Firestore and merges into SQLite.
  Future<void> pullFromFirestore() async {
    try {
      final remote = await remoteDataSource.fetchAllReports();
      for (final r in remote) {
        if (r.reportId == null) continue;

        // Use raw getReportById that ignores is_deleted so we don't
        // attempt a duplicate INSERT on soft-deleted rows.
        final local = await localDataSource.getReportByIdAny(r.reportId!);
        final synced = r.copyWith(
          status: DbConstants.statusSynced,
          syncedAt: DateTime.now().millisecondsSinceEpoch,
        );

        if (local == null) {
          // Truly new — safe to insert
          await localDataSource.insertReport(synced);
        } else if (r.updatedAt > local.updatedAt) {
          // Remote is newer (or local was soft-deleted) — overwrite
          await localDataSource.updateReport(synced);
        }
        // else: local is up-to-date, skip
      }
      _log.info('pullFromFirestore → ${remote.length} reports processed');
    } catch (e, s) {
      _log.warning('pullFromFirestore failed', e, s);
    }
  }

  /// Generates a deterministic device ID for this install.
  static String _generateDeviceId() {
    final hash = sha256
        .convert(utf8.encode('election_monitor_device'))
        .toString();
    return hash.substring(0, 16);
  }
}
