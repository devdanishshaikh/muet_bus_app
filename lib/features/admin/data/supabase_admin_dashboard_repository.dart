import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_dashboard_data.dart';
import '../domain/admin_dashboard_repository.dart';

class SupabaseAdminDashboardRepository implements AdminDashboardRepository {
  const SupabaseAdminDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AdminDashboardData> load() async {
    final counts = await Future.wait<int>([
      _countAll('buses'),
      _countWhere('buses', 'status', 'active'),
      _countAll('drivers'),
      _countWhere('bus_assignments', 'active', true),
      _countAll('routes'),
      _countWhere('routes', 'status', 'active'),
      _countWhere('trips', 'status', 'active'),
    ]);

    return AdminDashboardData(
      totalBuses: counts[0],
      activeBuses: counts[1],
      totalDrivers: counts[2],
      activeDriverAssignments: counts[3],
      totalRoutes: counts[4],
      activeRoutes: counts[5],
      activeTrips: counts[6],
    );
  }

  Future<int> _countAll(String table) async {
    final rows = await _client.from(table).select('id');
    return rows.length;
  }

  Future<int> _countWhere(String table, String column, Object value) async {
    final rows = await _client.from(table).select('id').eq(column, value);
    return rows.length;
  }
}
