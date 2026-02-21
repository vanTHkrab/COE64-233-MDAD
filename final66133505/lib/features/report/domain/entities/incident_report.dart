/// Domain model for displaying an incident report in the UI.
///
/// Combines data from `incident_report`, `polling_station`, and
/// `violation_type` tables for a complete view.
class IncidentReport {
  final int id;
  final String description;
  final DateTime date;
  final String reporterName;

  // Polling station info
  final int stationId;
  final String stationName;
  final String zone;
  final String province;

  // Violation type info
  final int typeId;
  final String violationTypeName;
  final String severity;

  // AI analysis
  final String? aiResult;
  final double aiConfidence;

  // Evidence
  final String? evidencePhoto;

  // Sync status
  final bool isSynced;

  const IncidentReport({
    required this.id,
    required this.description,
    required this.date,
    required this.reporterName,
    required this.stationId,
    required this.stationName,
    required this.zone,
    required this.province,
    required this.typeId,
    required this.violationTypeName,
    required this.severity,
    this.aiResult,
    this.aiConfidence = 0.0,
    this.evidencePhoto,
    this.isSynced = false,
  });

  /// User-friendly title combining AI result or violation type name.
  String get title =>
      aiResult != null && aiResult!.isNotEmpty ? aiResult! : violationTypeName;

  /// Full location label.
  String get locationLabel => '$stationName ($zone, $province)';
}
