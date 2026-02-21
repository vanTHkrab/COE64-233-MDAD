/// Database constants used across the storage layer.
///
/// Centralises every magic string / number so changes propagate
/// automatically and typos are caught at compile time.
class DbConstants {
  DbConstants._();

  // ── Database identity ──────────────────────────────────────────────────
  static const String databaseName = 'election_monitor.db';
  static const int databaseVersion = 5;

  // ── Table names ────────────────────────────────────────────────────────
  static const String tablePollingStation = 'polling_station';
  static const String tableViolationType = 'violation_type';
  static const String tableIncidentReport = 'incident_report';

  // ── Firestore collection names ─────────────────────────────────────────
  static const String colPollingStations = 'polling_stations';
  static const String colViolationTypes = 'violation_types';
  static const String colIncidentReports = 'incident_reports';

  // ── Sync configuration ─────────────────────────────────────────────────
  static const int maxRetryCount = 5;
  static const String prefLastSyncTime = 'last_sync_time';

  // ── Firestore batch limit ──────────────────────────────────────────────
  static const int firestoreBatchLimit = 500;

  // ── Sync status values ─────────────────────────────────────────────────
  static const String statusPending = 'pending';
  static const String statusSynced = 'synced';
  static const String statusError = 'error';
}
