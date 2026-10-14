import 'admin_transport_management_data.dart';

abstract interface class AdminTransportManagementRepository {
  Future<List<AdminBus>> loadBuses();
  Future<void> saveBus(AdminBus bus);

  Future<List<AdminDriver>> loadDrivers();
  Future<void> updateDriverStatus(String driverId, String status);

  Future<List<AdminRoute>> loadRoutes();
  Future<void> saveRoute(AdminRoute route);

  Future<List<AdminStop>> loadStops(String routeId);
  Future<void> saveStop(AdminStop stop);

  Future<List<AdminBusDriverAssignment>> loadBusDriverAssignments();
  Future<void> assignDriverToBus({
    required String busId,
    required String driverId,
  });

  Future<List<AdminBusRouteAssignment>> loadBusRouteAssignments();
  Future<void> assignRouteToBus({
    required String busId,
    required String routeId,
  });

  Future<List<AdminRouteSchedule>> loadRouteSchedules();
  Future<void> saveRouteSchedule(AdminRouteSchedule schedule);
}
