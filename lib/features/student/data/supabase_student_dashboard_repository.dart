import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/student_dashboard_data.dart';
import '../domain/student_dashboard_repository.dart';

class SupabaseStudentDashboardRepository implements StudentDashboardRepository {
  const SupabaseStudentDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<StudentDashboardData?> load(String profileId) async {
    final student = await _client
        .from('students')
        .select('id, student_id')
        .eq('profile_id', profileId)
        .maybeSingle();

    if (student == null) {
      return null;
    }

    final studentRecordId = student['id'] as String;
    final studentId = student['student_id'] as String;
    final alertRows = await _client
        .from('student_alerts')
        .select('bus_id')
        .eq('student_id', studentRecordId)
        .eq('enabled', true);
    final alertBusIds = alertRows
        .map((row) => row['bus_id'] as String)
        .toSet()
        .toList();

    if (alertBusIds.isEmpty) {
      return StudentDashboardData(studentId: studentId);
    }

    final trip = await _client
        .from('trips')
        .select('id, bus_id, route_id, status, started_at')
        .eq('status', 'active')
        .inFilter('bus_id', alertBusIds)
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (trip == null) {
      return StudentDashboardData(studentId: studentId);
    }

    final bus = await _client
        .from('buses')
        .select('bus_number, bus_name, status')
        .eq('id', trip['bus_id'] as String)
        .maybeSingle();
    final route = await _client
        .from('routes')
        .select('name, description')
        .eq('id', trip['route_id'] as String)
        .maybeSingle();

    if (bus == null || route == null) {
      return StudentDashboardData(studentId: studentId);
    }

    return StudentDashboardData(
      studentId: studentId,
      activeTrip: ActiveTripSummary(
        tripId: trip['id'] as String,
        busId: trip['bus_id'] as String,
        routeId: trip['route_id'] as String,
        busNumber: bus['bus_number'] as String,
        busName: bus['bus_name'] as String,
        busStatus: bus['status'] as String,
        routeName: route['name'] as String,
        routeDescription: route['description'] as String?,
        tripStatus: trip['status'] as String,
        startedAt: DateTime.parse(trip['started_at'] as String),
      ),
    );
  }
}
