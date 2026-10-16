import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/student_route.dart';
import '../domain/student_routes_repository.dart';

class SupabaseStudentRoutesRepository implements StudentRoutesRepository {
  const SupabaseStudentRoutesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<StudentRoute>> loadRoutes() async {
    final rows = await _client
        .from('routes')
        .select(
          'id, name, description, status, '
          'stops(id, name, stop_order, latitude, longitude)',
        )
        .eq('status', 'active')
        .order('name');

    return rows.map(_parseRoute).toList();
  }

  @override
  Future<StudentRouteDetails?> loadRouteDetails(String routeId) async {
    final row = await _client
        .from('routes')
        .select(
          'id, name, description, status, '
          'stops(id, name, stop_order, latitude, longitude)',
        )
        .eq('id', routeId)
        .eq('status', 'active')
        .maybeSingle();

    if (row == null) {
      return null;
    }

    final route = _parseRoute(row);
    final activeTrip = await _client
        .from('trips')
        .select('id, bus_id, started_at')
        .eq('route_id', routeId)
        .eq('status', 'active')
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (activeTrip == null) {
      return StudentRouteDetails(route: route);
    }

    final bus = await _client
        .from('buses')
        .select('bus_number, bus_name, status')
        .eq('id', activeTrip['bus_id'] as String)
        .maybeSingle();

    return StudentRouteDetails(
      route: route,
      activeBus: bus == null
          ? null
          : ActiveRouteBus(
              busId: activeTrip['bus_id'] as String,
              busNumber: bus['bus_number'] as String,
              busName: bus['bus_name'] as String,
              status: bus['status'] as String,
            ),
    );
  }

  @override
  Future<List<StudentRouteDetails>> loadRoutesWithActiveBuses() async {
    final rows = await _client
        .from('routes')
        .select(
          'id, name, description, status, '
          'stops(id, name, stop_order, latitude, longitude)',
        )
        .eq('status', 'active')
        .order('name');

    final routes = rows.map(_parseRoute).toList();
    final routeDetails = <StudentRouteDetails>[];

    for (final route in routes) {
      final activeTrip = await _client
          .from('trips')
          .select('id, bus_id, started_at')
          .eq('route_id', route.id)
          .eq('status', 'active')
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (activeTrip == null) {
        routeDetails.add(StudentRouteDetails(route: route));
        continue;
      }

      final bus = await _client
          .from('buses')
          .select('bus_number, bus_name, status')
          .eq('id', activeTrip['bus_id'] as String)
          .maybeSingle();

      routeDetails.add(
        StudentRouteDetails(
          route: route,
          activeBus: bus == null
              ? null
              : ActiveRouteBus(
                  busId: activeTrip['bus_id'] as String,
                  busNumber: bus['bus_number'] as String,
                  busName: bus['bus_name'] as String,
                  status: bus['status'] as String,
                ),
        ),
      );
    }

    return routeDetails;
  }

  StudentRoute _parseRoute(Map<String, dynamic> row) {
    final rawStops =
        (row['stops'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((stop) {
              return StudentRouteStop(
                id: stop['id'] as String,
                name: stop['name'] as String,
                stopOrder: stop['stop_order'] as int,
                latitude: _parseCoordinate(stop['latitude']),
                longitude: _parseCoordinate(stop['longitude']),
              );
            })
            .toList()
          ..sort(
            (first, second) => first.stopOrder.compareTo(second.stopOrder),
          );

    return StudentRoute(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      status: row['status'] as String,
      stops: rawStops,
    );
  }

  double? _parseCoordinate(Object? value) {
    return value == null ? null : double.tryParse(value.toString());
  }
}
