import 'driver_dashboard_data.dart';

abstract interface class DriverDashboardRepository {
  Future<DriverDashboardData?> load(String profileId);

  Future<DriverTrip> startTrip({
    required String profileId,
    required DriverAssignment assignment,
  });

  Future<DriverTrip> endTrip({
    required String profileId,
    required String tripId,
  });
}
