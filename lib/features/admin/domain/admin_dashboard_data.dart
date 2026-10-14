class AdminDashboardData {
  const AdminDashboardData({
    required this.totalBuses,
    required this.activeBuses,
    required this.totalDrivers,
    required this.activeDriverAssignments,
    required this.totalRoutes,
    required this.activeRoutes,
    required this.activeTrips,
  });

  final int totalBuses;
  final int activeBuses;
  final int totalDrivers;
  final int activeDriverAssignments;
  final int totalRoutes;
  final int activeRoutes;
  final int activeTrips;

  bool get isEmpty =>
      totalBuses == 0 &&
      activeBuses == 0 &&
      totalDrivers == 0 &&
      activeDriverAssignments == 0 &&
      totalRoutes == 0 &&
      activeRoutes == 0 &&
      activeTrips == 0;
}
