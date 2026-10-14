class StudentDashboardData {
  const StudentDashboardData({required this.studentId, this.activeTrip});

  final String studentId;
  final ActiveTripSummary? activeTrip;
}

class ActiveTripSummary {
  const ActiveTripSummary({
    this.tripId,
    this.busId,
    this.routeId,
    required this.busNumber,
    required this.busName,
    required this.busStatus,
    required this.routeName,
    required this.routeDescription,
    required this.tripStatus,
    required this.startedAt,
  });

  final String? tripId;
  final String? busId;
  final String? routeId;
  final String busNumber;
  final String busName;
  final String busStatus;
  final String routeName;
  final String? routeDescription;
  final String tripStatus;
  final DateTime startedAt;
}
