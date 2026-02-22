
class PollingStation {
  final int stationId;
  final String stationName;
  final String zone;
  final String province;
  final int updatedAt;
  final bool isDeleted;
  final bool isSynced;

  PollingStation({
    required this.stationId,
    required this.stationName,
    required this.zone,
    required this.province,
    this.updatedAt = 0,
    this.isDeleted = false,
    this.isSynced = false,
  });
}