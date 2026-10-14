import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/driver_dashboard_data.dart';
import '../domain/driver_dashboard_repository.dart';

class SupabaseDriverDashboardRepository implements DriverDashboardRepository {
  const SupabaseDriverDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DriverDashboardData?> load(String profileId) async {
    final profile = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', profileId)
        .maybeSingle();
    final driver = await _client
        .from('drivers')
        .select('id, status')
        .eq('profile_id', profileId)
        .maybeSingle();

    if (profile == null || driver == null) {
      return null;
    }

    final driverId = driver['id'] as String;
    final busAssignment = await _client
        .from('bus_assignments')
        .select('bus_id, assigned_at, active')
        .eq('driver_id', driverId)
        .order('assigned_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final assignment = await _loadAssignment(busAssignment);
    final activeTrip = await _loadActiveTrip(driverId);

    return DriverDashboardData(
      driverId: driverId,
      driverName: profile['full_name'] as String,
      assignment: assignment,
      activeTrip: activeTrip,
    );
  }

  @override
  Future<DriverTrip> startTrip({
    required String profileId,
    required DriverAssignment assignment,
  }) async {
    final dashboard = await load(profileId);
    if (dashboard == null || !dashboard.canStartTrip) {
      throw const FormatException(
        'A valid active bus and route assignment is required to start a trip.',
      );
    }

    final row = await _client
        .from('trips')
        .insert({
          'bus_id': assignment.busId,
          'driver_id': dashboard.driverId,
          'route_id': assignment.routeId,
          'status': 'active',
          'started_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id, status, started_at, ended_at')
        .single();
    return _parseTrip(row);
  }

  @override
  Future<DriverTrip> endTrip({
    required String profileId,
    required String tripId,
  }) async {
    final dashboard = await load(profileId);
    if (dashboard?.activeTrip?.id != tripId) {
      throw const FormatException('Only your own active trip can be ended.');
    }

    final row = await _client
        .from('trips')
        .update({
          'status': 'completed',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', tripId)
        .eq('status', 'active')
        .select('id, status, started_at, ended_at')
        .single();
    return _parseTrip(row);
  }

  Future<DriverAssignment?> _loadAssignment(
    Map<String, dynamic>? busAssignment,
  ) async {
    if (busAssignment == null) {
      return null;
    }

    final busId = busAssignment['bus_id'] as String;
    final bus = await _client
        .from('buses')
        .select('id, bus_number, bus_name, status')
        .eq('id', busId)
        .maybeSingle();
    final routeAssignment = await _client
        .from('route_assignments')
        .select('route_id, active, assigned_at')
        .eq('bus_id', busId)
        .order('assigned_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (bus == null || routeAssignment == null) {
      return null;
    }

    final route = await _client
        .from('routes')
        .select('id, name, description, status')
        .eq('id', routeAssignment['route_id'] as String)
        .maybeSingle();
    if (route == null) {
      return null;
    }

    return DriverAssignment(
      busId: bus['id'] as String,
      busNumber: bus['bus_number'] as String,
      busName: bus['bus_name'] as String,
      busStatus: bus['status'] as String,
      routeId: route['id'] as String,
      routeName: route['name'] as String,
      routeDescription: route['description'] as String?,
      routeStatus: route['status'] as String,
      isActive:
          (busAssignment['active'] as bool? ?? false) &&
          (routeAssignment['active'] as bool? ?? false),
    );
  }

  Future<DriverTrip?> _loadActiveTrip(String driverId) async {
    final row = await _client
        .from('trips')
        .select('id, status, started_at, ended_at')
        .eq('driver_id', driverId)
        .eq('status', 'active')
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : _parseTrip(row);
  }

  DriverTrip _parseTrip(Map<String, dynamic> row) {
    return DriverTrip(
      id: row['id'] as String,
      status: row['status'] as String,
      startedAt: DateTime.parse(row['started_at'] as String),
      endedAt: row['ended_at'] == null
          ? null
          : DateTime.tryParse(row['ended_at'].toString()),
    );
  }
}
