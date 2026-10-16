class DriverDashboardData {
  const DriverDashboardData({
    required this.driverId,
    required this.driverName,
    required this.driverStatus,
    this.assignment,
    this.activeTrip,
  });

  final String driverId;
  final String driverName;
  final String driverStatus;
  final DriverAssignment? assignment;
  final DriverTrip? activeTrip;

  bool get canStartTrip =>
      assignment != null &&
      assignment!.isActive &&
      assignment!.busStatus == 'active' &&
      assignment!.routeStatus == 'active' &&
      activeTrip == null;
}

class DriverAssignment {
  const DriverAssignment({
    required this.busId,
    required this.busNumber,
    required this.busName,
    required this.busStatus,
    required this.routeId,
    required this.routeName,
    required this.routeDescription,
    required this.routeStatus,
    required this.isActive,
  });

  final String busId;
  final String busNumber;
  final String busName;
  final String busStatus;
  final String routeId;
  final String routeName;
  final String? routeDescription;
  final String routeStatus;
  final bool isActive;
}

class DriverTrip {
  const DriverTrip({
    required this.id,
    required this.status,
    required this.startedAt,
    this.endedAt,
  });

  final String id;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
}
