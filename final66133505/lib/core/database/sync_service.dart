import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/db_constants.dart';
import '../network/network_info.dart';
import 'local_datasource.dart';
import 'remote_datasource.dart';

/// Orchestrates bidirectional synchronisation between SQLite and Firestore.
///
/// **Algorithm (on every [syncAll] call):**
///   1. Check connectivity.
///   2. Pull remote changes (since last sync).
///   3. Merge via Last-Writer-Wins (LWW) using `updated_at`.
///   4. Push local pending reports with exponential retry.
///   5. Update `synced_at`, `status`, and persisted `last_sync_time`.
///
/// Master-data tables (`polling_station`, `violation_type`) are pull-only.
class SyncService {
  SyncService({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.networkInfo,
  });

  final LocalDataSource localDataSource;
  final RemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  static final _log = Logger('SyncService');

  StreamSubscription<bool>? _connectivitySub;

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  /// Call once at app startup. Subscribes to connectivity changes and
  /// triggers a sync whenever the device comes back online.
  Future<void> initialize() async {
    _log.info('SyncService initializing…');

    // Initial sync if online.
    final connected = await networkInfo.isConnected;
    if (connected) {
      try {
        await syncAll();
      } catch (e, s) {
        _log.warning('Initial sync failed (non-fatal)', e, s);
      }
    }

    // Auto-sync on connectivity restore.
    _connectivitySub = networkInfo.onConnectivityChanged.listen((online) {
      if (online) {
        _log.info('Connectivity restored → triggering sync');
        syncAll().catchError((e, s) {
          _log.warning('Auto-sync failed', e, s);
        });
      }
    });

    _log.info('SyncService initialized');
  }

  /// Cancels the connectivity listener (e.g. on app teardown).
  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _log.info('SyncService disposed');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Full sync cycle
  // ═══════════════════════════════════════════════════════════════════════════

  /// **Startup pull-first bootstrap.**
  ///
  /// Called once on app open — always pulls the latest data from Firestore
  /// into SQLite before the UI is shown. This ensures the user always sees
  /// up-to-date data from other devices.
  ///
  /// Order:
  ///   1. Pull reference data (stations → types).
  ///   2. Pull & merge all incident reports.
  ///
  /// Safe to call when offline — gracefully skips with a log warning.
  Future<void> pullFromFirestoreOnStartup() async {
    if (!await networkInfo.isConnected) {
      _log.info(
        'pullFromFirestoreOnStartup skipped — offline, using local data',
      );
      return;
    }

    _log.info('━━━ pullFromFirestoreOnStartup START ━━━');

    try {
      await _pullStations();
      await _pullViolationTypes();
      await _pullAndMergeReports();
      await _saveLastSyncTime(DateTime.now().millisecondsSinceEpoch);
      _log.info('━━━ pullFromFirestoreOnStartup COMPLETE ━━━');
    } catch (e, s) {
      _log.warning('pullFromFirestoreOnStartup failed (non-fatal)', e, s);
      // Non-fatal — app continues with whatever is in local SQLite.
    }
  }

  /// Runs the complete Pull → Merge → Push cycle.
  Future<void> syncAll() async {
    if (!await networkInfo.isConnected) {
      _log.info('syncAll skipped — offline');
      return;
    }

    _log.info('━━━ syncAll START ━━━');

    try {
      // 1. Pull master data (reference tables).
      await _pullStations();
      await _pullViolationTypes();

      // 2. Pull + merge incident reports.
      await _pullAndMergeReports();

      // 3. Push local pending reports.
      await _pushPendingReports();

      // 4. Persist last sync time.
      await _saveLastSyncTime(DateTime.now().millisecondsSinceEpoch);

      _log.info('━━━ syncAll COMPLETE ━━━');
    } catch (e, s) {
      _log.severe('syncAll failed', e, s);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pull — Master Data
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pullStations() async {
    try {
      final remote = await remoteDataSource.fetchAllStations();
      if (remote.isNotEmpty) {
        await localDataSource.upsertStations(remote);
        _log.info('Pulled ${remote.length} polling stations');
      }
    } catch (e, s) {
      _log.warning('_pullStations failed (non-fatal)', e, s);
    }
  }

  Future<void> _pullViolationTypes() async {
    try {
      final remote = await remoteDataSource.fetchAllTypes();
      if (remote.isNotEmpty) {
        await localDataSource.upsertTypes(remote);
        _log.info('Pulled ${remote.length} violation types');
      }
    } catch (e, s) {
      _log.warning('_pullViolationTypes failed (non-fatal)', e, s);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pull + Merge — Incident Reports (LWW conflict resolution)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pullAndMergeReports() async {
    try {
      final lastSync = await _getLastSyncTime();
      final remoteReports = await remoteDataSource.fetchReportsSince(lastSync);

      if (remoteReports.isEmpty) {
        _log.fine('No remote report changes since $lastSync');
        return;
      }

      _log.info('Pulled ${remoteReports.length} remote report(s) to merge');

      for (final remote in remoteReports) {
        if (remote.reportId == null) continue;

        final local = await localDataSource.getReportById(remote.reportId!);

        if (local == null) {
          // New report from another device — insert locally.
          await localDataSource.insertReport(
            remote.copyWith(
              status: DbConstants.statusSynced,
              syncedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
          _log.fine('Inserted new remote report ${remote.reportId}');
        } else {
          // ── LWW conflict resolution ────────────────────────────────
          if (remote.updatedAt > local.updatedAt) {
            // Remote wins — overwrite local.
            await localDataSource.updateReport(
              remote.copyWith(
                status: DbConstants.statusSynced,
                syncedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
            _log.fine(
              'LWW: remote wins for ${remote.reportId} '
              '(remote=${remote.updatedAt} > local=${local.updatedAt})',
            );
          } else {
            // Local wins — keep local, will be pushed.
            _log.fine(
              'LWW: local wins for ${remote.reportId} '
              '(local=${local.updatedAt} >= remote=${remote.updatedAt})',
            );
          }
        }
      }
    } catch (e, s) {
      _log.warning('_pullAndMergeReports failed', e, s);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Push — Pending Reports (exponential retry)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pushPendingReports() async {
    final pending = await localDataSource.getPendingReports();
    if (pending.isEmpty) {
      _log.fine('No pending reports to push');
      return;
    }

    _log.info('Pushing ${pending.length} pending report(s)');

    for (final report in pending) {
      if (report.reportId == null) continue;
      await _pushSingleReport(report);
    }
  }

  Future<void> _pushSingleReport(IncidentReportEntity report) async {
    final retries = report.retryCount;
    if (retries >= DbConstants.maxRetryCount) {
      _log.warning(
        'Skipping ${report.reportId} — max retries (${DbConstants.maxRetryCount}) reached',
      );
      return;
    }

    // Exponential backoff delay (skip on first attempt).
    if (retries > 0) {
      final delay = Duration(seconds: pow(2, retries).toInt());
      _log.fine('Retry #$retries for ${report.reportId} — waiting $delay');
      await Future.delayed(delay);
    }

    try {
      await remoteDataSource.uploadReport(report);
      final now = DateTime.now().millisecondsSinceEpoch;
      await localDataSource.markAsSynced(report.reportId!, now);
      _log.fine('Pushed ${report.reportId} ✓');
    } catch (e, s) {
      _log.warning('Push failed for ${report.reportId}', e, s);
      await localDataSource.markSyncError(
        report.reportId!,
        retries + 1,
        e.toString(),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Last sync time persistence
  // ─────────────────────────────────────────────────────────────────────────

  Future<int> _getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(DbConstants.prefLastSyncTime) ?? 0;
  }

  Future<void> _saveLastSyncTime(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(DbConstants.prefLastSyncTime, timestamp);
    _log.fine('Saved last_sync_time = $timestamp');
  }
}
