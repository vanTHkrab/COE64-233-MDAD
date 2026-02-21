import '../constants/db_constants.dart';

/// Contains every DDL statement and seed script for the local SQLite database.
///
/// Kept separate from [AppDatabase] so table definitions are easy to review
/// and unit-test in isolation.
class Tables {
  Tables._();

  // ═══════════════════════════════════════════════════════════════════════════
  // CREATE TABLE statements
  // ═══════════════════════════════════════════════════════════════════════════

  /// Master data – pulled from Firestore only.
  static const String createPollingStation =
      '''
    CREATE TABLE ${DbConstants.tablePollingStation} (
      station_id   INTEGER PRIMARY KEY,
      station_name TEXT    NOT NULL,
      zone         TEXT    NOT NULL,
      province     TEXT    NOT NULL,

      updated_at   INTEGER NOT NULL,
      is_deleted   INTEGER DEFAULT 0,
      is_synced    INTEGER DEFAULT 1
    );
  ''';

  /// Master data – pulled from Firestore only.
  static const String createViolationType =
      '''
    CREATE TABLE ${DbConstants.tableViolationType} (
      type_id   INTEGER PRIMARY KEY,
      type_name TEXT    NOT NULL,
      severity  TEXT    NOT NULL,

      updated_at INTEGER NOT NULL,
      is_deleted INTEGER DEFAULT 0,
      is_synced  INTEGER DEFAULT 1
    );
  ''';

  /// Distributed data – full bidirectional sync with conflict resolution.
  static const String createIncidentReport =
      '''
    CREATE TABLE ${DbConstants.tableIncidentReport} (
      report_id      INTEGER PRIMARY KEY AUTOINCREMENT,
      station_id     INTEGER NOT NULL,
      type_id        INTEGER NOT NULL,

      reporter_name  TEXT,
      description    TEXT,
      evidence_photo TEXT,
      timestamp      INTEGER NOT NULL,

      ai_result      TEXT,
      ai_confidence  REAL    DEFAULT 0.0,

      user_id        TEXT    NOT NULL,
      device_id      TEXT    NOT NULL,

      status         TEXT    DEFAULT '${DbConstants.statusPending}',
      is_deleted     INTEGER DEFAULT 0,
      updated_at     INTEGER NOT NULL,
      synced_at      INTEGER,
      retry_count    INTEGER DEFAULT 0,
      last_error     TEXT,

      FOREIGN KEY (station_id) REFERENCES ${DbConstants.tablePollingStation}(station_id),
      FOREIGN KEY (type_id)    REFERENCES ${DbConstants.tableViolationType}(type_id)
    );
  ''';

  // ═══════════════════════════════════════════════════════════════════════════
  // Indices for query performance
  // ═══════════════════════════════════════════════════════════════════════════

  static const String indexReportStation =
      '''
    CREATE INDEX idx_report_station ON ${DbConstants.tableIncidentReport}(station_id);
  ''';

  static const String indexReportType =
      '''
    CREATE INDEX idx_report_type ON ${DbConstants.tableIncidentReport}(type_id);
  ''';

  static const String indexReportTimestamp =
      '''
    CREATE INDEX idx_report_timestamp ON ${DbConstants.tableIncidentReport}(timestamp);
  ''';

  static const String indexReportStatus =
      '''
    CREATE INDEX idx_report_status ON ${DbConstants.tableIncidentReport}(status);
  ''';

  // ═══════════════════════════════════════════════════════════════════════════
  // Seed data (inserted on first install)
  // ═══════════════════════════════════════════════════════════════════════════

  /// All DDL + seed statements to run inside `onCreate`.
  static List<String> get allCreateStatements => [
    createPollingStation,
    createViolationType,
    createIncidentReport,
    indexReportStation,
    indexReportType,
    indexReportTimestamp,
    indexReportStatus,
    ..._seedPollingStations,
    ..._seedViolationTypes,
    ..._seedIncidentReports,
  ];

  // ── polling_station seed ───────────────────────────────────────────────

  static final List<String> _seedPollingStations = [
    _insertStation(101, 'โรงเรียนวัดพระมหาธาตุ', 'เขต 1', 'นครศรีธรรมราช'),
    _insertStation(102, 'เต็นท์หน้าตลาดท่าวัง', 'เขต 1', 'นครศรีธรรมราช'),
    _insertStation(103, 'ศาลากลางหมู่บ้านคีรีวง', 'เขต 2', 'นครศรีธรรมราช'),
    _insertStation(104, 'หอประชุมอำเภอทุ่งสง', 'เขต 3', 'นครศรีธรรมราช'),
  ];

  static String _insertStation(
    int id,
    String name,
    String zone,
    String province,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return "INSERT INTO ${DbConstants.tablePollingStation} "
        "(station_id, station_name, zone, province, updated_at) "
        "VALUES ($id, '$name', '$zone', '$province', $now);";
  }

  // ── violation_type seed ────────────────────────────────────────────────

  static final List<String> _seedViolationTypes = [
    _insertType(1, 'ซื้อสิทธิ์ขายเสียง (Buying Votes)', 'High'),
    _insertType(2, 'ขนคนไปลงคะแนน (Transportation)', 'High'),
    _insertType(3, 'หาเสียงเกินเวลา (Overtime Campaign)', 'Medium'),
    _insertType(4, 'ทำลายป้ายหาเสียง (Vandalism)', 'Low'),
    _insertType(5, 'เจ้าหน้าที่วางตัวไม่เป็นกลาง (Bias Official)', 'High'),
  ];

  static String _insertType(int id, String name, String severity) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return "INSERT INTO ${DbConstants.tableViolationType} "
        "(type_id, type_name, severity, updated_at) "
        "VALUES ($id, '$name', '$severity', $now);";
  }

  // ── incident_report seed ───────────────────────────────────────────────

  static final List<String> _seedIncidentReports = [
    _insertReport(
      101,
      1,
      'พลเมืองดี 01',
      'พบเห็นการแจกเงินบริเวณหน้าหน่วย',
      null,
      '2026-02-08 09:30:00',
      'Money',
      0.95,
    ),
    _insertReport(
      102,
      3,
      'สมชาย ใจกล้า',
      'มีการเปิดรถแห่เสียงดังรบกวน',
      null,
      '2026-02-08 10:15:00',
      'Crowd',
      0.75,
    ),
    _insertReport(
      103,
      5,
      'Anonymous',
      'เจ้าหน้าที่พูดจาชี้นำผู้ลงคะแนน',
      null,
      '2026-02-08 11:00:00',
      null,
      0.0,
    ),
  ];

  static String _insertReport(
    int stationId,
    int typeId,
    String reporterName,
    String description,
    String? evidencePhoto,
    String timestampStr,
    String? aiResult,
    double aiConfidence,
  ) {
    final ts = DateTime.parse(timestampStr).millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;
    final photoVal = evidencePhoto == null ? 'NULL' : "'$evidencePhoto'";
    final aiVal = aiResult == null ? 'NULL' : "'$aiResult'";
    return "INSERT INTO ${DbConstants.tableIncidentReport} "
        "(station_id, type_id, reporter_name, description, "
        "evidence_photo, timestamp, ai_result, ai_confidence, "
        "user_id, device_id, status, updated_at) "
        "VALUES ($stationId, $typeId, '$reporterName', "
        "'$description', $photoVal, $ts, $aiVal, $aiConfidence, "
        "'seed_user', 'seed_device', '${DbConstants.statusPending}', $now);";
  }
}
