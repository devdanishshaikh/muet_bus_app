import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/student_live_tracking.dart';
import '../domain/student_live_tracking_repository.dart';

class SupabaseStudentLiveTrackingRepository
    implements StudentLiveTrackingRepository {
  const SupabaseStudentLiveTrackingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<StudentLiveTracking>> loadActiveBuses() {
    return _loadActiveTrips();
  }

  @override
  Future<StudentLiveTracking?> load({String? routeId, String? busId}) async {
    if (routeId == null && busId == null) {
      return null;
    }

    final trips = await _loadActiveTrips(routeId: routeId, busId: busId);
    return trips.isEmpty ? null : trips.first;
  }

  Future<List<StudentLiveTracking>> _loadActiveTrips({
    String? routeId,
    String? busId,
  }) async {
    final List<Map<String, dynamic>> rows;
    if (routeId != null && busId != null) {
      rows = await _client
          .from('trips')
          .select('id, bus_id, route_id, status, started_at')
          .eq('route_id', routeId)
          .eq('bus_id', busId)
          .eq('status', 'active')
          .order('started_at', ascending: false);
    } else if (routeId != null) {
      rows = await _client
          .from('trips')
          .select('id, bus_id, route_id, status, started_at')
          .eq('route_id', routeId)
          .eq('status', 'active')
          .order('started_at', ascending: false);
    } else if (busId != null) {
      rows = await _client
          .from('trips')
          .select('id, bus_id, route_id, status, started_at')
          .eq('bus_id', busId)
          .eq('status', 'active')
          .order('started_at', ascending: false);
    } else {
      rows = await _client
          .from('trips')
          .select('id, bus_id, route_id, status, started_at')
          .eq('status', 'active')
          .order('started_at', ascending: false);
    }

    if (rows.isEmpty) {
      return const [];
    }

    final busIds = <String>{};
    final routeIds = <String>{};
    final tripIds = <String>[];
    for (final trip in rows) {
      busIds.add(trip['bus_id'] as String);
      routeIds.add(trip['route_id'] as String);
      tripIds.add(trip['id'] as String);
    }

    final results = await Future.wait<Object?>([
      _client
          .from('buses')
          .select('id, bus_number, bus_name, status')
          .inFilter('id', busIds.toList()),
      _client
          .from('routes')
          .select('id, name')
          .inFilter('id', routeIds.toList()),
      _loadLatestLocations(tripIds),
    ]);

    final busRows = results[0] as List<Map<String, dynamic>>;
    final routeRows = results[1] as List<Map<String, dynamic>>;
    final latestLocations = results[2] as Map<String, StudentBusLocation>;

    final busesById = <String, Map<String, dynamic>>{
      for (final row in busRows) row['id'] as String: row,
    };
    final routesById = <String, Map<String, dynamic>>{
      for (final row in routeRows) row['id'] as String: row,
    };

    return [
      for (final trip in rows)
        _buildSnapshot(
          trip: trip,
          bus: busesById[trip['bus_id'] as String],
          route: routesById[trip['route_id'] as String],
          location: latestLocations[trip['id'] as String],
        ),
    ];
  }

  StudentLiveTracking _buildSnapshot({
    required Map<String, dynamic> trip,
    required Map<String, dynamic>? bus,
    required Map<String, dynamic>? route,
    required StudentBusLocation? location,
  }) {
    final tripId = trip['id'] as String;
    final busId = trip['bus_id'] as String;
    final routeId = trip['route_id'] as String;
    return StudentLiveTracking(
      tripId: tripId,
      busId: busId,
      routeId: routeId,
      busNumber: bus?['bus_number'] as String? ?? 'Unknown',
      busName: bus?['bus_name'] as String? ?? 'Unknown',
      busStatus: bus?['status'] as String? ?? 'unknown',
      routeName: route?['name'] as String? ?? 'Unknown',
      tripStatus: trip['status'] as String,
      tripStartedAt: DateTime.parse(trip['started_at'] as String),
      location: location,
    );
  }

  Future<Map<String, StudentBusLocation>> _loadLatestLocations(
    List<String> tripIds,
  ) async {
    if (tripIds.isEmpty) {
      return const {};
    }

    final latestLocations = <String, StudentBusLocation>{};
    final futures = tripIds.map((tripId) async {
      final row = await _client
          .from('bus_locations')
          .select('latitude, longitude, speed, recorded_at')
          .eq('trip_id', tripId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) {
        return;
      }
      final location = _parseLocation(row);
      if (location != null && location.isValid) {
        latestLocations[tripId] = location;
      }
    });
    await Future.wait(futures);
    return latestLocations;
  }

  StudentBusLocation? _parseLocation(Map<String, dynamic> row) {
    final latitude = double.tryParse(row['latitude'].toString());
    final longitude = double.tryParse(row['longitude'].toString());
    final recordedAt = DateTime.tryParse(row['recorded_at'].toString());
    if (latitude == null || longitude == null || recordedAt == null) {
      return null;
    }

    final location = StudentBusLocation(
      latitude: latitude,
      longitude: longitude,
      recordedAt: recordedAt.toLocal(),
      speedMetersPerSecond: double.tryParse(row['speed']?.toString() ?? ''),
    );
    return location.isValid ? location : null;
  }
}
