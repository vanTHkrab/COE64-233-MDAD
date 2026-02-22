import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

import '../constants/db_constants.dart';
import 'local_datasource.dart';

/// Handles all Cloud Firestore read / write operations.
///
/// **Rules:**
///   • Never touches SQLite.
///   • Never performs conflict resolution — the sync service owns that.
///   • Works exclusively with maps / entity objects.
class RemoteDataSource {
  RemoteDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static final _log = Logger('RemoteDataSource');

  // ─────────────────────────────────────────────────────────────────────────
  // Polling Station (pull-only)
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches all polling stations from Firestore.
  /// Records fetched from remote are always considered synced.
  Future<List<PollingStationEntity>> fetchAllStations() async {
    final snap = await _firestore
        .collection(DbConstants.colPollingStations)
        .get();
    _log.fine('fetchAllStations → ${snap.docs.length} docs');
    return snap.docs.map((doc) {
      final data = doc.data();
      data['station_id'] = int.tryParse(doc.id) ?? data['station_id'];
      // Records that exist in Firestore are by definition synced
      data['is_synced'] = 1;
      return PollingStationEntity.fromMap(data);
    }).toList();
  }

  /// Pushes a list of polling stations to Firestore (seed / initial push).
  /// `is_synced` and `is_deleted` are local-only bookkeeping fields — stripped
  /// before sending to Firestore.
  Future<void> pushStations(List<PollingStationEntity> entities) async {
    final batches = _chunkList(entities, DbConstants.firestoreBatchLimit);
    for (final chunk in batches) {
      final batch = _firestore.batch();
      for (final e in chunk) {
        final ref = _firestore
            .collection(DbConstants.colPollingStations)
            .doc('${e.stationId}');
        // Strip local-only fields before writing to Firestore
        final data = e.toMap()
          ..remove('is_synced')
          ..remove('is_deleted');
        batch.set(ref, data, SetOptions(merge: true));
      }
      await batch.commit();
    }
    _log.info('pushStations → ${entities.length} docs');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Violation Type (pull-only)
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches all violation types from Firestore.
  Future<List<ViolationTypeEntity>> fetchAllTypes() async {
    final snap = await _firestore
        .collection(DbConstants.colViolationTypes)
        .get();
    _log.fine('fetchAllTypes → ${snap.docs.length} docs');
    return snap.docs.map((doc) {
      final data = doc.data();
      data['type_id'] = int.tryParse(doc.id) ?? data['type_id'];
      return ViolationTypeEntity.fromMap(data);
    }).toList();
  }

  /// Pushes a list of violation types to Firestore (seed / initial push).
  Future<void> pushTypes(List<ViolationTypeEntity> entities) async {
    final batches = _chunkList(entities, DbConstants.firestoreBatchLimit);
    for (final chunk in batches) {
      final batch = _firestore.batch();
      for (final e in chunk) {
        final ref = _firestore
            .collection(DbConstants.colViolationTypes)
            .doc('${e.typeId}');
        batch.set(ref, e.toMap(), SetOptions(merge: true));
      }
      await batch.commit();
    }
    _log.info('pushTypes → ${entities.length} docs');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Incident Report (bidirectional sync)
  // ─────────────────────────────────────────────────────────────────────────

  /// Uploads a single report to Firestore.
  Future<void> uploadReport(IncidentReportEntity entity) async {
    if (entity.reportId == null) {
      throw ArgumentError('report_id must not be null when uploading');
    }
    final ref = _firestore
        .collection(DbConstants.colIncidentReports)
        .doc('${entity.reportId}');
    await ref.set(entity.toMap(), SetOptions(merge: true));
    _log.fine('uploadReport id=${entity.reportId}');
  }

  /// Updates a remote report document (e.g. soft-delete propagation).
  Future<void> updateRemoteReport(IncidentReportEntity entity) async {
    if (entity.reportId == null) return;
    final ref = _firestore
        .collection(DbConstants.colIncidentReports)
        .doc('${entity.reportId}');
    await ref.update(entity.toMap());
    _log.fine('updateRemoteReport id=${entity.reportId}');
  }

  /// Fetches remote reports modified since [sinceTimestamp] (Unix ms).
  ///
  /// Returns at most [limit] documents per page. Pass `null` for first page.
  Future<List<IncidentReportEntity>> fetchReportsSince(
    int sinceTimestamp, {
    int limit = DbConstants.firestoreBatchLimit,
  }) async {
    final snap = await _firestore
        .collection(DbConstants.colIncidentReports)
        .where('updated_at', isGreaterThan: sinceTimestamp)
        .orderBy('updated_at')
        .limit(limit)
        .get();
    _log.fine('fetchReportsSince($sinceTimestamp) → ${snap.docs.length} docs');
    return snap.docs.map((doc) {
      final data = doc.data();
      data['report_id'] = int.tryParse(doc.id);
      return IncidentReportEntity.fromMap(data);
    }).toList();
  }

  /// Fetches all reports from Firestore (full pull).
  Future<List<IncidentReportEntity>> fetchAllReports() async {
    final snap = await _firestore
        .collection(DbConstants.colIncidentReports)
        .get();
    _log.fine('fetchAllReports → ${snap.docs.length} docs');
    return snap.docs.map((doc) {
      final data = doc.data();
      data['report_id'] = int.tryParse(doc.id);
      return IncidentReportEntity.fromMap(data);
    }).toList();
  }

  /// Deletes a report document from Firestore permanently.
  Future<void> deleteRemoteReport(int reportId) async {
    try {
      await _firestore
          .collection(DbConstants.colIncidentReports)
          .doc('$reportId')
          .delete();
      _log.fine('deleteRemoteReport id=$reportId');
    } catch (e, s) {
      _log.warning('deleteRemoteReport failed id=$reportId', e, s);
      rethrow;
    }
  }

  /// Batch-uploads multiple reports using Firestore batched writes.
  Future<void> uploadReports(List<IncidentReportEntity> entities) async {
    final chunks = _chunkList(entities, DbConstants.firestoreBatchLimit);
    for (final chunk in chunks) {
      final batch = _firestore.batch();
      for (final e in chunk) {
        if (e.reportId == null) continue;
        final ref = _firestore
            .collection(DbConstants.colIncidentReports)
            .doc('${e.reportId}');
        batch.set(ref, e.toMap(), SetOptions(merge: true));
      }
      await batch.commit();
    }
    _log.info('uploadReports → ${entities.length} docs');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Splits a list into chunks of at most [size] elements.
  List<List<T>> _chunkList<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      final end = (i + size > list.length) ? list.length : i + size;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }
}
