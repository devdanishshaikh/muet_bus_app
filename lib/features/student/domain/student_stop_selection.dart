class StudentStopSelection {
  const StudentStopSelection({
    required this.id,
    required this.stopId,
    required this.busId,
    required this.radiusMeters,
    required this.enabled,
    this.triggeredAt,
    this.busNumber,
    this.busName,
    this.stopName,
    this.routeName,
  });

  final String id;
  final String stopId;
  final String busId;
  final double radiusMeters;
  final bool enabled;
  final DateTime? triggeredAt;
  final String? busNumber;
  final String? busName;
  final String? stopName;
  final String? routeName;
}
