import 'admin_dashboard_data.dart';
import 'admin_live_monitoring_data.dart';

abstract interface class AdminDashboardRepository {
  Future<AdminDashboardData> load();

  /// Load active trips with their latest location for the dashboard overview.
  Future<List<MonitoredBus>> loadActiveTrips();
}
