import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';

import '../constants/db_constants.dart';
import 'app_database.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Entity classes (plain Dart objects — NO Firestore / sync logic)
// ═══════════════════════════════════════════════════════════════════════════════

/// Represents a row in `polling_station`.
class PollingStationEntity {
  final int stationId;
  final String stationName;
  final String zone;
  final String province;
  final int updatedAt;
  final bool isDeleted;
  final bool isSynced;

  const PollingStationEntity({
    required this.stationId,
    required this.stationName,
    required this.zone,
    required this.province,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = true,
  });

  factory PollingStationEntity.fromMap(Map<String, dynamic> map) {
    return PollingStationEntity(
      stationId: map['station_id'] as int,
      stationName: map['station_name'] as String,
      zone: map['zone'] as String,
      province: map['province'] as String,
      updatedAt: map['updated_at'] as int,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      isSynced: (map['is_synced'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
    'station_id': stationId,
    'station_name': stationName,
    'zone': zone,
    'province': province,
    'updated_at': updatedAt,
    'is_deleted': isDeleted ? 1 : 0,
    'is_synced': isSynced ? 1 : 0,
  };
}

/// Represents a row in `violation_type`.
class ViolationTypeEntity {
  final int typeId;
  final String typeName;
  final String severity;
  final int updatedAt;
  final bool isDeleted;
  final bool isSynced;

  const ViolationTypeEntity({
    required this.typeId,
    required this.typeName,
    required this.severity,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = true,
  });

  factory ViolationTypeEntity.fromMap(Map<String, dynamic> map) {
    return ViolationTypeEntity(
      typeId: map['type_id'] as int,
      typeName: map['type_name'] as String,
      severity: map['severity'] as String,
      updatedAt: map['updated_at'] as int,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      isSynced: (map['is_synced'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
    'type_id': typeId,
    'type_name': typeName,
    'severity': severity,
    'updated_at': updatedAt,
    'is_deleted': isDeleted ? 1 : 0,
    'is_synced': isSynced ? 1 : 0,
  };
}

/// Represents a row in `incident_report`.
class IncidentReportEntity {
  /// UUID string — generated client-side.
  final int? reportId;
  final int stationId;
  final int typeId;
  final String reporterName;
  final String description;
  final String? evidencePhoto;

  /// Unix millisecond timestamp stored as INTEGER.
  final String timestamp;

  final String? aiResult;
  final double aiConfidence;
  final String userId;
  final String deviceId;

  /// `pending` | `synced` | `error`
  final String status;
  final bool isDeleted;
  final int updatedAt;
  final int? syncedAt;
  final int retryCount;
  final String? lastError;

  /// Convenience getter used by the UI layer.
  bool get isSynced => status == DbConstants.statusSynced;

  const IncidentReportEntity({
    this.reportId,
    required this.stationId,
    required this.typeId,
    required this.reporterName,
    required this.description,
    this.evidencePhoto,
    required this.timestamp,
    this.aiResult,
    this.aiConfidence = 0.0,
    this.userId = '',
    this.deviceId = '',
    this.status = DbConstants.statusPending,
    this.isDeleted = false,
    this.updatedAt = 0,
    this.syncedAt,
    this.retryCount = 0,
    this.lastError,
  });

  factory IncidentReportEntity.fromMap(Map<String, dynamic> map) {
    return IncidentReportEntity(
      reportId: map['report_id'] as int?,
      stationId: map['station_id'] as int,
      typeId: map['type_id'] as int,
      reporterName: (map['reporter_name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      evidencePhoto: map['evidence_photo'] as String?,
      timestamp: _parseTimestamp(map['timestamp']),
      aiResult: map['ai_result'] as String?,
      aiConfidence: (map['ai_confidence'] as num?)?.toDouble() ?? 0.0,
      userId: (map['user_id'] as String?) ?? '',
      deviceId: (map['device_id'] as String?) ?? '',
      status: (map['status'] as String?) ?? DbConstants.statusPending,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      updatedAt: (map['updated_at'] as int?) ?? 0,
      syncedAt: map['synced_at'] as int?,
      retryCount: (map['retry_count'] as int?) ?? 0,
      lastError: map['last_error'] as String?,
    );
  }

  /// Handles both INTEGER (Unix ms) and legacy TEXT timestamps.
  static String _parseTimestamp(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
    }
    return (value as String?) ?? DateTime.now().toIso8601String();
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'station_id': stationId,
      'type_id': typeId,
      'reporter_name': reporterName,
      'description': description,
      'evidence_photo': evidencePhoto,
      'timestamp': _timestampToInt(),
      'ai_result': aiResult,
      'ai_confidence': aiConfidence,
      'user_id': userId,
      'device_id': deviceId,
      'status': status,
      'is_deleted': isDeleted ? 1 : 0,
      'updated_at': updatedAt,
      'synced_at': syncedAt,
      'retry_count': retryCount,
      'last_error': lastError,
    };
    if (reportId != null) map['report_id'] = reportId;
    return map;
  }

  /// Converts the ISO-8601 / custom timestamp string back to Unix ms.
  int _timestampToInt() {
    final parsed = DateTime.tryParse(timestamp);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// Returns a copy with selected fields overridden.
  IncidentReportEntity copyWith({
    int? reportId,
    int? stationId,
    int? typeId,
    String? reporterName,
    String? description,
    String? evidencePhoto,
    String? timestamp,
    String? aiResult,
    double? aiConfidence,
    String? userId,
    String? deviceId,
    String? status,
    bool? isDeleted,
    int? updatedAt,
    int? syncedAt,
    int? retryCount,
    String? lastError,
  }) {
    return IncidentReportEntity(
      reportId: reportId ?? this.reportId,
      stationId: stationId ?? this.stationId,
      typeId: typeId ?? this.typeId,
      reporterName: reporterName ?? this.reporterName,
      description: description ?? this.description,
      evidencePhoto: evidencePhoto ?? this.evidencePhoto,
      timestamp: timestamp ?? this.timestamp,
      aiResult: aiResult ?? this.aiResult,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Local Data Source — pure SQLite operations, NO sync / Firestore logic
// ═══════════════════════════════════════════════════════════════════════════════

/// Low-level CRUD operations against the local SQLite database.
///
/// **Rules:**
///   • Never performs network calls.
///   • Never resolves conflicts — that's the repository / sync service's job.
///   • Every public method receives or returns plain entity objects.
class LocalDataSource {
  LocalDataSource({required this.appDatabase});

  final AppDatabase appDatabase;
  static final _log = Logger('LocalDataSource');

  Future<Database> get _db => appDatabase.database;

  // ─────────────────────────────────────────────────────────────────────────
  // Polling Station
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<PollingStationEntity>> getAllStations() async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tablePollingStation,
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'station_id ASC',
    );
    _log.fine('getAllStations → ${rows.length} rows');
    return rows.map(PollingStationEntity.fromMap).toList();
  }

  Future<PollingStationEntity?> getStationById(int id) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tablePollingStation,
      where: 'station_id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : PollingStationEntity.fromMap(rows.first);
  }

  Future<void> upsertStation(PollingStationEntity entity) async {
    final db = await _db;
    await db.insert(
      DbConstants.tablePollingStation,
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _log.fine('upsertStation id=${entity.stationId}');
  }

  /// Inserts a new station without a pre-set ID and returns the assigned ID.
  Future<int> insertNewStation(PollingStationEntity entity) async {
    final db = await _db;
    final map = entity.toMap()..remove('station_id');
    final id = await db.insert(
      DbConstants.tablePollingStation,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _log.fine('insertNewStation → id=$id');
    return id;
  }

  Future<void> upsertStations(List<PollingStationEntity> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in entities) {
      batch.insert(
        DbConstants.tablePollingStation,
        e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _log.fine('upsertStations → ${entities.length} rows');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Violation Type
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<ViolationTypeEntity>> getAllTypes() async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tableViolationType,
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'type_id ASC',
    );
    _log.fine('getAllTypes → ${rows.length} rows');
    return rows.map(ViolationTypeEntity.fromMap).toList();
  }

  Future<ViolationTypeEntity?> getTypeById(int id) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tableViolationType,
      where: 'type_id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ViolationTypeEntity.fromMap(rows.first);
  }

  Future<void> upsertType(ViolationTypeEntity entity) async {
    final db = await _db;
    await db.insert(
      DbConstants.tableViolationType,
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _log.fine('upsertType id=${entity.typeId}');
  }

  /// Inserts a new type without a pre-set ID and returns the assigned ID.
  Future<int> insertNewType(ViolationTypeEntity entity) async {
    final db = await _db;
    final map = entity.toMap()..remove('type_id');
    final id = await db.insert(
      DbConstants.tableViolationType,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _log.fine('insertNewType → id=$id');
    return id;
  }

  Future<void> upsertTypes(List<ViolationTypeEntity> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in entities) {
      batch.insert(
        DbConstants.tableViolationType,
        e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _log.fine('upsertTypes → ${entities.length} rows');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Incident Report
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<IncidentReportEntity>> getAllReports() async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tableIncidentReport,
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'timestamp DESC',
    );
    _log.fine('getAllReports → ${rows.length} rows');
    return rows.map(IncidentReportEntity.fromMap).toList();
  }

  Future<IncidentReportEntity?> getReportById(int id) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tableIncidentReport,
      where: 'report_id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : IncidentReportEntity.fromMap(rows.first);
  }

  /// Like [getReportById] but also returns soft-deleted rows.
  /// Used during pull-sync to avoid duplicate INSERT on already-existing rows.
  Future<IncidentReportEntity?> getReportByIdAny(int id) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tableIncidentReport,
      where: 'report_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : IncidentReportEntity.fromMap(rows.first);
  }

  /// Inserts a new report. SQLite auto-assigns report_id (AUTOINCREMENT).
  /// Returns the auto-assigned integer ID.
  Future<int> insertReport(IncidentReportEntity entity) async {
    final db = await _db;
    final rowId = await db.insert(
      DbConstants.tableIncidentReport,
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    _log.fine('insertReport id=$rowId');
    return rowId;
  }

  /// Full row replacement (used by conflict merge).
  Future<void> updateReport(IncidentReportEntity entity) async {
    final db = await _db;
    await db.update(
      DbConstants.tableIncidentReport,
      entity.toMap(),
      where: 'report_id = ?',
      whereArgs: [entity.reportId],
    );
    _log.fine('updateReport id=${entity.reportId}');
  }

  /// Marks a report as synced after successful upload.
  Future<void> markAsSynced(int reportId, int syncedAt) async {
    final db = await _db;
    await db.update(
      DbConstants.tableIncidentReport,
      {
        'status': DbConstants.statusSynced,
        'synced_at': syncedAt,
        'retry_count': 0,
        'last_error': null,
      },
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
    _log.fine('markAsSynced id=$reportId');
  }

  /// Records a sync failure for retry tracking.
  Future<void> markSyncError(int reportId, int retryCount, String error) async {
    final db = await _db;
    await db.update(
      DbConstants.tableIncidentReport,
      {
        'status': DbConstants.statusError,
        'retry_count': retryCount,
        'last_error': error,
      },
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
    _log.fine('markSyncError id=$reportId retry=$retryCount');
  }

  /// Returns reports that need to be pushed to Firestore.
  Future<List<IncidentReportEntity>> getPendingReports() async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tableIncidentReport,
      where:
          "(status = ? OR status = ?) AND is_deleted = 0 AND retry_count < ?",
      whereArgs: [
        DbConstants.statusPending,
        DbConstants.statusError,
        DbConstants.maxRetryCount,
      ],
      orderBy: 'updated_at ASC',
    );
    _log.fine('getPendingReports → ${rows.length} rows');
    return rows.map(IncidentReportEntity.fromMap).toList();
  }

  /// Soft-deletes a report (sets is_deleted = 1, status = pending).
  Future<void> softDeleteReport(int reportId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      DbConstants.tableIncidentReport,
      {'is_deleted': 1, 'updated_at': now, 'status': DbConstants.statusPending},
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
    _log.fine('softDeleteReport id=$reportId');
  }

  /// Permanently removes a report row from SQLite.
  Future<void> hardDeleteReport(int reportId) async {
    final db = await _db;
    await db.delete(
      DbConstants.tableIncidentReport,
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
    _log.fine('hardDeleteReport id=$reportId');
  }

  /// Count of reports that have not been synced yet.
  Future<int> getUnsyncedReportCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DbConstants.tableIncidentReport} '
      "WHERE status != ? AND is_deleted = 0",
      [DbConstants.statusSynced],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns the most recent `updated_at` value from all reports.
  Future<int> getLatestReportUpdatedAt() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT MAX(updated_at) as max_ts FROM ${DbConstants.tableIncidentReport}',
    );
    return (result.first['max_ts'] as int?) ?? 0;
  }
}
