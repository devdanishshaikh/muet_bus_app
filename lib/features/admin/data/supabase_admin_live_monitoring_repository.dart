import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_live_monitoring_data.dart';
import '../domain/admin_live_monitoring_repository.dart';

class SupabaseAdminLiveMonitoringRepository
    implements AdminLiveMonitoringRepository {
  const SupabaseAdminLiveMonitoringRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MonitoredBus>> loadActiveTrips() async {
    final trips = await _client
        .from('trips')
        .select('id, bus_id, driver_id, route_id, status, started_at')
        .eq('status', 'active')
        .order('started_at', ascending: false);

    if (trips.isEmpty) {
      return const [];
    }

    // Collect unique IDs to batch-resolve related entities.
    final busIds = <String>{};
    final driverIds = <String>{};
    final routeIds = <String>{};
    final tripIds = <String>[];
    for (final trip in trips) {
      busIds.add(trip['bus_id'] as String);
      driverIds.add(trip['driver_id'] as String);
      routeIds.add(trip['route_id'] as String);
      tripIds.add(trip['id'] as String);
    }

    // Resolve bus, route and driver data in parallel.
    final results = await Future.wait<Object?>([
      _client
          .from('buses')
          .select('id, bus_number, bus_name')
          .inFilter('id', busIds.toList()),
      _client.from('routes').select('id, name').inFilter('id', routeIds.toList()),
      _loadDriverNames(driverIds),
      _loadLatestLocations(tripIds),
    ]);

    final busRows = results[0] as List<Map<String, dynamic>>;
    final routeRows = results[1] as List<Map<String, dynamic>>;
    final driverNames = results[2] as Map<String, String>;
    final latestLocations = results[3] as Map<String, MonitoredBusLocation>;

    final busesById = <String, Map<String, dynamic>>{
      for (final row in busRows) row['id'] as String: row,
    };
    final routesById = <String, Map<String, dynamic>>{
      for (final row in routeRows) row['id'] as String: row,
    };

    final monitored = <MonitoredBus>[];
    for (final trip in trips) {
      final busId = trip['bus_id'] as String;
      final routeId = trip['route_id'] as String;
      final driverId = trip['driver_id'] as String;
      final tripId = trip['id'] as String;
      final bus = busesById[busId];
      final route = routesById[routeId];

      monitored.add(MonitoredBus(
        tripId: tripId,
        busId: busId,
        busNumber: bus?['bus_number'] as String? ?? 'Unknown',
        busName: bus?['bus_name'] as String? ?? 'Unknown',
        routeId: routeId,
        routeName: route?['name'] as String? ?? 'Unknown',
        driverName: driverNames[driverId] ?? 'Unknown driver',
        tripStatus: trip['status'] as String,
        tripStartedAt: DateTime.parse(trip['started_at'] as String),
        location: latestLocations[tripId],
      ));
    }

    return monitored;
  }

  @override
  Stream<AdminLiveMonitoringSnapshot> watchActiveTrips() async* {
    final buses = await loadActiveTrips();
    var snapshot = AdminLiveMonitoringSnapshot(buses: buses);
    yield snapshot;

    if (buses.isEmpty) {
      // Nothing to subscribe to.
      yield snapshot.copyWith(
        realtimeStatus: AdminMonitoringStatus.connected,
      );
      return;
    }

    final controller = StreamController<AdminLiveMonitoringSnapshot>();
    final channel = _client.channel('admin-live-monitoring');

    // Build a map by tripId for fast updates.
    final busByTripId = <String, MonitoredBus>{
      for (final bus in buses) bus.tripId: bus,
    };

    // Subscribe to bus_locations inserts for every active trip.
    // We listen for ALL inserts and filter by tripId in the callback
    // so we need only one channel.
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bus_locations',
          callback: (payload) {
            final record = payload.newRecord;
            final tripId = record['trip_id']?.toString();
            if (tripId == null || !busByTripId.containsKey(tripId)) {
              return;
            }
            final location = _parseLocation(record);
            if (location == null || !location.isValid) {
              return;
            }
            busByTripId[tripId] = busByTripId[tripId]!.withLocation(location);
            snapshot = snapshot.copyWith(
              buses: busByTripId.values.toList(),
              clearRealtimeError: true,
            );
            controller.add(snapshot);
          },
        )
        .subscribe((status, error) {
          final next = switch (status) {
            RealtimeSubscribeStatus.subscribed => snapshot.copyWith(
                realtimeStatus: AdminMonitoringStatus.connected,
                clearRealtimeError: true,
              ),
            RealtimeSubscribeStatus.closed => snapshot.copyWith(
                realtimeStatus: AdminMonitoringStatus.disconnected,
                realtimeError: 'Live updates are disconnected.',
              ),
            RealtimeSubscribeStatus.channelError ||
            RealtimeSubscribeStatus.timedOut => snapshot.copyWith(
                realtimeStatus: AdminMonitoringStatus.reconnecting,
                realtimeError: 'Live updates are reconnecting.',
              ),
          };
          snapshot = next;
          controller.add(snapshot);
        });

    try {
      yield* controller.stream;
    } finally {
      await _client.removeChannel(channel);
      await controller.close();
    }
  }

  /// Load driver full_name for each driver ID (never loads CNIC).
  Future<Map<String, String>> _loadDriverNames(Set<String> driverIds) async {
    if (driverIds.isEmpty) {
      return const {};
    }

    final driverRows = await _client
        .from('drivers')
        .select('id, profile_id')
        .inFilter('id', driverIds.toList());
    if (driverRows.isEmpty) {
      return const {};
    }

    final profileIds = <String>{
      for (final row in driverRows) row['profile_id'] as String,
    };
    final profileRows = await _client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', profileIds.toList());

    final namesByProfileId = <String, String>{
      for (final row in profileRows) row['id'] as String: row['full_name'] as String,
    };

    return <String, String>{
      for (final row in driverRows)
        row['id'] as String:
            namesByProfileId[row['profile_id'] as String] ?? 'Unknown driver',
    };
  }

  /// Load the latest bus_location for each trip.
  Future<Map<String, MonitoredBusLocation>> _loadLatestLocations(
    List<String> tripIds,
  ) async {
    if (tripIds.isEmpty) {
      return const {};
    }

    final locations = <String, MonitoredBusLocation>{};
    // Load the most recent location per trip.
    // We query individually per trip to use the indexed (trip_id, recorded_at desc) path.
    final futures = tripIds.map((tripId) async {
      final row = await _client
          .from('bus_locations')
          .select('latitude, longitude, speed, heading, recorded_at')
          .eq('trip_id', tripId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        final loc = _parseLocation(row);
        if (loc != null && loc.isValid) {
          locations[tripId] = loc;
        }
      }
    });
    await Future.wait(futures);
    return locations;
  }

  static MonitoredBusLocation? _parseLocation(Map<String, dynamic> row) {
    final latitude = double.tryParse(row['latitude'].toString());
    final longitude = double.tryParse(row['longitude'].toString());
    final recordedAtRaw = row['recorded_at']?.toString();
    if (latitude == null || longitude == null || recordedAtRaw == null) {
      return null;
    }
    final recordedAt = DateTime.tryParse(recordedAtRaw);
    if (recordedAt == null) {
      return null;
    }
    return MonitoredBusLocation(
      latitude: latitude,
      longitude: longitude,
      recordedAt: recordedAt.toLocal(),
      speed: double.tryParse(row['speed']?.toString() ?? ''),
      heading: double.tryParse(row['heading']?.toString() ?? ''),
    );
  }
}
