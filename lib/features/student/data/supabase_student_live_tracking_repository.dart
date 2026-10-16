import 'dart:async';

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

  @override
  Stream<List<StudentLiveTracking>> watchActiveBuses() async* {
    final channel = _client.channel('student-live-tracking');

    // Store the latest state of all active buses
    final Map<String, StudentLiveTracking> busState = {};

    // Controller for emitting state updates
    final controller = StreamController<List<StudentLiveTracking>>.broadcast();

    // Subscribe to bus_locations changes for active trips
    final subscription = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bus_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: '', // We'll filter by active trips in the callback
          ),
          callback: (payload) async {
            await _handleLocationInsert(payload, busState, controller);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bus_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: '',
          ),
          callback: (payload) async {
            await _handleLocationUpdate(payload, busState, controller);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'bus_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: '',
          ),
          callback: (payload) async {
            await _handleLocationDelete(payload, busState, controller);
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Initial load when subscription is ready
            _loadAndEmit(busState, controller);
          } else if (status == RealtimeSubscribeStatus.closed) {
            // Channel closed, will be resubscribed
          } else if (error != null) {
            controller.addError(error);
          }
        });

    // Also subscribe to trip status changes for active trips
    final tripsChannel = _client.channel('student-live-tracking-trips');
    tripsChannel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: 'active',
          ),
          callback: (payload) async {
            // Trip status changed - reload active buses
            await _loadAndEmit(busState, controller);
          },
        )
        .subscribe();

    // Initial load
    await _loadAndEmit(busState, controller);

    // Yield initial state
    yield* controller.stream;

    // Forward all subsequent updates
    await for (final state in controller.stream) {
      yield state;
    }

    // Cleanup
    await subscription.unsubscribe();
    await channel.unsubscribe();
    await controller.close();
  }

  Future<void> _handleLocationInsert(
    PostgresChangePayload payload,
    Map<String, StudentLiveTracking> busState,
    StreamController<List<StudentLiveTracking>> controller,
  ) async {
    final tripId = payload.newRecord['trip_id'] as String?;
    if (tripId == null) return;

    // Verify the trip is active
    final trip = await _client
        .from('trips')
        .select('id, bus_id, route_id, status, started_at')
        .eq('id', tripId)
        .eq('status', 'active')
        .maybeSingle();

    if (trip == null) return; // Trip not active

    await _updateBusFromLocation(busState, controller, tripId, payload.newRecord);
  }

  Future<void> _handleLocationUpdate(
    PostgresChangePayload payload,
    Map<String, StudentLiveTracking> busState,
    StreamController<List<StudentLiveTracking>> controller,
  ) async {
    final tripId = payload.newRecord['trip_id'] as String?;
    if (tripId == null) return;

    // Verify the trip is still active
    final trip = await _client
        .from('trips')
        .select('id, bus_id, route_id, status, started_at')
        .eq('id', tripId)
        .eq('status', 'active')
        .maybeSingle();

    if (trip == null) {
      // Trip no longer active, remove from state
      busState.remove(tripId);
      controller.add(busState.values.toList());
      return;
    }

    await _updateBusFromLocation(busState, controller, tripId, payload.newRecord);
  }

  Future<void> _handleLocationDelete(
    PostgresChangePayload payload,
    Map<String, StudentLiveTracking> busState,
    StreamController<List<StudentLiveTracking>> controller,
  ) async {
    final tripId = payload.oldRecord['trip_id'] as String?;
    if (tripId == null) return;

    busState.remove(tripId);
    controller.add(busState.values.toList());
  }

  Future<void> _updateBusFromLocation(
    Map<String, StudentLiveTracking> busState,
    StreamController<List<StudentLiveTracking>> controller,
    String tripId,
    Map<String, dynamic> locationRecord,
  ) async {
    // Load bus and route info for this trip
    final trip = await _client
        .from('trips')
        .select('id, bus_id, route_id, status, started_at')
        .eq('id', tripId)
        .eq('status', 'active')
        .maybeSingle();

    if (trip == null) return;

    final bus = await _client
        .from('buses')
        .select('id, bus_number, bus_name, status')
        .eq('id', trip['bus_id'] as String)
        .maybeSingle();

    final route = await _client
        .from('routes')
        .select('id, name')
        .eq('id', trip['route_id'] as String)
        .maybeSingle();

    final location = _parseLocation(locationRecord);

    if (bus == null || route == null || location == null) return;

    final updated = StudentLiveTracking(
      tripId: tripId,
      busId: trip['bus_id'] as String,
      routeId: trip['route_id'] as String,
      busNumber: bus['bus_number'] as String? ?? 'Unknown',
      busName: bus['bus_name'] as String? ?? 'Unknown',
      busStatus: bus['status'] as String? ?? 'unknown',
      routeName: route['name'] as String? ?? 'Unknown',
      tripStatus: trip['status'] as String,
      tripStartedAt: DateTime.parse(trip['started_at'] as String),
      location: location,
    );

    busState[tripId] = updated;
    controller.add(busState.values.toList());
  }

  Future<void> _loadAndEmit(
    Map<String, StudentLiveTracking> busState,
    StreamController<List<StudentLiveTracking>> controller,
  ) async {
    final trips = await _loadActiveTrips();

    busState.clear();
    for (final tracking in trips) {
      if (tracking.hasValidLocation) {
        busState[tracking.tripId] = tracking;
      }
    }

    controller.add(busState.values.toList());
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