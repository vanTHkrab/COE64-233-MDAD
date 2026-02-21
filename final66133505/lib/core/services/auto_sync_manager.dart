import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../database/sync_service.dart';
import '../di/injection.dart';
import '../network/network_info.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Sync status model
// ═════════════════════════════════════════════════════════════════════════════

enum SyncState { idle, syncing, synced, offline, error }

class SyncStatus {
  final SyncState state;
  final int pendingCount;
  final String? errorMessage;
  final DateTime? lastSyncTime;

  const SyncStatus({
    this.state = SyncState.idle,
    this.pendingCount = 0,
    this.errorMessage,
    this.lastSyncTime,
  });

  SyncStatus copyWith({
    SyncState? state,
    int? pendingCount,
    String? errorMessage,
    DateTime? lastSyncTime,
  }) {
    return SyncStatus(
      state: state ?? this.state,
      pendingCount: pendingCount ?? this.pendingCount,
      errorMessage: errorMessage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  bool get isSyncing => state == SyncState.syncing;
  bool get isOffline => state == SyncState.offline;
  bool get hasPending => pendingCount > 0;
}

// ═════════════════════════════════════════════════════════════════════════════
// AutoSyncManager — production-grade background sync orchestrator
// ═════════════════════════════════════════════════════════════════════════════

/// Manages automatic background synchronization with:
///   • Periodic sync every [syncInterval]
///   • Connectivity-aware sync (auto-syncs when back online)
///   • App lifecycle-aware (syncs on resume, pauses on background)
///   • Stream-based status broadcasting for reactive UI
///   • Debounce protection to prevent overlapping syncs
class AutoSyncManager with WidgetsBindingObserver {
  AutoSyncManager({
    required SyncService syncService,
    required NetworkInfo networkInfo,
    this.syncInterval = const Duration(seconds: 30),
  }) : _syncService = syncService,
       _networkInfo = networkInfo;

  final SyncService _syncService;
  final NetworkInfo _networkInfo;
  final Duration syncInterval;

  static final _log = Logger('AutoSyncManager');

  // ── State ────────────────────────────────────────────────────────────────
  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = const SyncStatus();
  bool _isSyncing = false;
  bool _isInitialized = false;

  Timer? _periodicTimer;
  StreamSubscription<bool>? _connectivitySub;

  /// Reactive stream of sync status changes.
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Current sync status snapshot.
  SyncStatus get currentStatus => _currentStatus;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Call once at app startup after DI is configured.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _log.info('AutoSyncManager initializing…');

    // Register as lifecycle observer.
    WidgetsBinding.instance.addObserver(this);

    // Check initial connectivity and set status.
    final online = await _networkInfo.isConnected;
    if (!online) {
      _emit(_currentStatus.copyWith(state: SyncState.offline));
    }

    // Listen to connectivity changes.
    _connectivitySub = _networkInfo.onConnectivityChanged.listen((online) {
      if (online) {
        _log.info('Back online → triggering sync');
        _emit(_currentStatus.copyWith(state: SyncState.idle));
        requestSync();
      } else {
        _log.info('Gone offline');
        _emit(_currentStatus.copyWith(state: SyncState.offline));
      }
    });

    // Start periodic timer.
    _startPeriodicSync();

    // Initial sync.
    await requestSync();

    _log.info('AutoSyncManager initialized ✓');
  }

  /// Tear down all timers, subscriptions, and observers.
  void dispose() {
    _periodicTimer?.cancel();
    _connectivitySub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _statusController.close();
    _isInitialized = false;
    _log.info('AutoSyncManager disposed');
  }

  // ── App lifecycle ────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _log.fine('App resumed → restarting periodic sync');
        _startPeriodicSync();
        requestSync();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _log.fine('App paused → stopping periodic sync');
        _periodicTimer?.cancel();
        break;
      default:
        break;
    }
  }

  // ── Sync control ─────────────────────────────────────────────────────────

  /// Request a sync. Safe to call multiple times — concurrent syncs are
  /// debounced automatically.
  Future<void> requestSync() async {
    if (_isSyncing) {
      _log.fine('Sync already in progress — skipping');
      return;
    }

    final online = await _networkInfo.isConnected;
    if (!online) {
      // Update pending count even when offline.
      await _refreshPendingCount();
      _emit(_currentStatus.copyWith(state: SyncState.offline));
      return;
    }

    _isSyncing = true;
    _emit(_currentStatus.copyWith(state: SyncState.syncing));

    try {
      await _syncService.syncAll();
      await _refreshPendingCount();
      _emit(
        _currentStatus.copyWith(
          state: SyncState.synced,
          lastSyncTime: DateTime.now(),
          errorMessage: null,
        ),
      );
      _log.fine('Background sync completed ✓');

      // Revert to idle after a short display delay.
      Future.delayed(const Duration(seconds: 3), () {
        if (_currentStatus.state == SyncState.synced) {
          _emit(_currentStatus.copyWith(state: SyncState.idle));
        }
      });
    } catch (e, s) {
      _log.warning('Background sync failed', e, s);
      await _refreshPendingCount();
      _emit(
        _currentStatus.copyWith(
          state: SyncState.error,
          errorMessage: e.toString(),
        ),
      );

      // Revert to idle after showing error.
      Future.delayed(const Duration(seconds: 5), () {
        if (_currentStatus.state == SyncState.error) {
          _emit(_currentStatus.copyWith(state: SyncState.idle));
        }
      });
    } finally {
      _isSyncing = false;
    }
  }

  // ── Internals ────────────────────────────────────────────────────────────

  void _startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(syncInterval, (_) => requestSync());
  }

  Future<void> _refreshPendingCount() async {
    try {
      final repo = sl<IncidentReportRepository>();
      final count = await repo.getUnsyncedCount();
      _currentStatus = _currentStatus.copyWith(pendingCount: count);
    } catch (_) {}
  }

  void _emit(SyncStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
}
