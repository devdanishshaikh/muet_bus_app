import 'admin_dashboard_data.dart';

abstract interface class AdminDashboardRepository {
  Future<AdminDashboardData> load();
}
