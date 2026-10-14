import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_transport_management_data.dart';
import '../domain/admin_transport_management_repository.dart';

class SupabaseAdminTransportManagementRepository
    implements AdminTransportManagementRepository {
  const SupabaseAdminTransportManagementRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AdminBus>> loadBuses() async {
    final rows = await _client
        .from('buses')
        .select('id, bus_number, bus_name, status')
        .order('bus_number');
    return rows
        .map(
          (row) => AdminBus(
            id: row['id'] as String,
            busNumber: row['bus_number'] as String,
            busName: row['bus_name'] as String,
            status: row['status'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveBus(AdminBus bus) async {
    final values = {
      'bus_number': bus.busNumber,
      'bus_name': bus.busName,
      'status': bus.status,
    };
    if (bus.id == null) {
      await _client.from('buses').insert(values);
    } else {
      await _client.from('buses').update(values).eq('id', bus.id!);
    }
  }

  @override
  Future<List<AdminDriver>> loadDrivers() async {
    final results = await Future.wait<Object?>([
      _client.from('drivers').select('id, profile_id, phone, status'),
      _client.from('profiles').select('id, full_name'),
    ]);
    final driverRows = results[0] as List<Map<String, dynamic>>? ?? const [];
    final profileRows = results[1] as List<Map<String, dynamic>>? ?? const [];
    final namesByProfileId = <String, String>{
      for (final row in profileRows)
        row['id'] as String: row['full_name'] as String,
    };
    return driverRows
        .map(
          (row) => AdminDriver(
            id: row['id'] as String,
            name: namesByProfileId[row['profile_id'] as String] ?? 'Unknown driver',
            phone: row['phone'] as String?,
            status: row['status'] as String,
          ),
        )
        .toList()
      ..sort((first, second) => first.name.compareTo(second.name));
  }

  @override
  Future<void> updateDriverStatus(String driverId, String status) async {
    await _client
        .from('drivers')
        .update({'status': status})
        .eq('id', driverId);
  }

  @override
  Future<List<AdminRoute>> loadRoutes() async {
    final rows = await _client
        .from('routes')
        .select('id, name, description, status')
        .order('name');
    return rows
        .map(
          (row) => AdminRoute(
            id: row['id'] as String,
            name: row['name'] as String,
            description: row['description'] as String?,
            status: row['status'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveRoute(AdminRoute route) async {
    final values = {
      'name': route.name,
      'description': route.description,
      'status': route.status,
    };
    if (route.id == null) {
      await _client.from('routes').insert(values);
    } else {
      await _client.from('routes').update(values).eq('id', route.id!);
    }
  }

  @override
  Future<List<AdminStop>> loadStops(String routeId) async {
    final rows = await _client
        .from('stops')
        .select('id, route_id, name, latitude, longitude, stop_order')
        .eq('route_id', routeId)
        .order('stop_order');
    return rows
        .map(
          (row) => AdminStop(
            id: row['id'] as String,
            routeId: row['route_id'] as String,
            name: row['name'] as String,
            latitude: _asDouble(row['latitude']),
            longitude: _asDouble(row['longitude']),
            stopOrder: row['stop_order'] as int,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveStop(AdminStop stop) async {
    final values = {
      'route_id': stop.routeId,
      'name': stop.name,
      'latitude': stop.latitude,
      'longitude': stop.longitude,
      'stop_order': stop.stopOrder,
    };
    if (stop.id == null) {
      await _client.from('stops').insert(values);
    } else {
      await _client.from('stops').update(values).eq('id', stop.id!);
    }
  }

  @override
  Future<List<AdminBusDriverAssignment>> loadBusDriverAssignments() async {
    final results = await Future.wait<Object?>([
      _client.from('bus_assignments').select('id, bus_id, driver_id, active'),
      loadBuses(),
      loadDrivers(),
    ]);
    final busesById = {for (final bus in results[1] as List<AdminBus>) bus.id!: bus};
    final driversById = {
      for (final driver in results[2] as List<AdminDriver>) driver.id: driver,
    };
    return (results[0] as List<Map<String, dynamic>>)
        .map(
          (row) => AdminBusDriverAssignment(
            id: row['id'] as String,
            busId: row['bus_id'] as String,
            busName: busesById[row['bus_id']]?.busNumber ?? 'Unknown bus',
            driverId: row['driver_id'] as String,
            driverName: driversById[row['driver_id']]?.name ?? 'Unknown driver',
            active: row['active'] as bool,
          ),
        )
        .toList()
      ..sort((first, second) => second.active == first.active
          ? first.busName.compareTo(second.busName)
          : (second.active ? 1 : -1));
  }

  @override
  Future<void> assignDriverToBus({
    required String busId,
    required String driverId,
  }) async {
    await Future.wait([
      _client
          .from('bus_assignments')
          .update({'active': false})
          .eq('bus_id', busId)
          .eq('active', true),
      _client
          .from('bus_assignments')
          .update({'active': false})
          .eq('driver_id', driverId)
          .eq('active', true),
    ]);
    await _client.from('bus_assignments').insert({
      'bus_id': busId,
      'driver_id': driverId,
      'active': true,
    });
  }

  @override
  Future<List<AdminBusRouteAssignment>> loadBusRouteAssignments() async {
    final results = await Future.wait<Object?>([
      _client.from('route_assignments').select('id, bus_id, route_id, active'),
      loadBuses(),
      loadRoutes(),
    ]);
    final busesById = {for (final bus in results[1] as List<AdminBus>) bus.id!: bus};
    final routesById = {
      for (final route in results[2] as List<AdminRoute>) route.id!: route,
    };
    return (results[0] as List<Map<String, dynamic>>)
        .map(
          (row) => AdminBusRouteAssignment(
            id: row['id'] as String,
            busId: row['bus_id'] as String,
            busName: busesById[row['bus_id']]?.busNumber ?? 'Unknown bus',
            routeId: row['route_id'] as String,
            routeName: routesById[row['route_id']]?.name ?? 'Unknown route',
            active: row['active'] as bool,
          ),
        )
        .toList()
      ..sort((first, second) => second.active == first.active
          ? first.busName.compareTo(second.busName)
          : (second.active ? 1 : -1));
  }

  @override
  Future<void> assignRouteToBus({
    required String busId,
    required String routeId,
  }) async {
    await _client
        .from('route_assignments')
        .update({'active': false})
        .eq('bus_id', busId)
        .eq('active', true);
    await _client.from('route_assignments').insert({
      'bus_id': busId,
      'route_id': routeId,
      'active': true,
    });
  }

  @override
  Future<List<AdminRouteSchedule>> loadRouteSchedules() async {
    final results = await Future.wait<Object?>([
      _client
          .from('route_schedules')
          .select('id, route_id, stop_id, day_of_week, scheduled_time')
          .order('day_of_week')
          .order('scheduled_time'),
      loadRoutes(),
      _client.from('stops').select('id, name'),
    ]);
    final routesById = {
      for (final route in results[1] as List<AdminRoute>) route.id!: route,
    };
    final stopNames = <String, String>{
      for (final row in results[2] as List<Map<String, dynamic>>)
        row['id'] as String: row['name'] as String,
    };
    return (results[0] as List<Map<String, dynamic>>)
        .map(
          (row) => AdminRouteSchedule(
            id: row['id'] as String,
            routeId: row['route_id'] as String,
            routeName: routesById[row['route_id']]?.name ?? 'Unknown route',
            stopId: row['stop_id'] as String,
            stopName: stopNames[row['stop_id']] ?? 'Unknown stop',
            dayOfWeek: row['day_of_week'] as int,
            scheduledTime: row['scheduled_time'].toString(),
          ),
        )
        .toList();
  }

  @override
  Future<void> saveRouteSchedule(AdminRouteSchedule schedule) async {
    final values = {
      'route_id': schedule.routeId,
      'stop_id': schedule.stopId,
      'day_of_week': schedule.dayOfWeek,
      'scheduled_time': schedule.scheduledTime,
    };
    if (schedule.id == null) {
      await _client.from('route_schedules').insert(values);
    } else {
      await _client.from('route_schedules').update(values).eq('id', schedule.id!);
    }
  }

  static double _asDouble(Object? value) =>
      value is num ? value.toDouble() : double.parse(value.toString());
}
