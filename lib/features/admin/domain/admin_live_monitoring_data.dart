/// Realtime connection status for the admin monitoring channel.
enum AdminMonitoringStatus {
  connecting,
  connected,
  reconnecting,
  disconnected,
  error,
}

/// A snapshot of all active buses the admin is monitoring.
class AdminLiveMonitoringSnapshot {
  const AdminLiveMonitoringSnapshot({
    required this.buses,
    this.realtimeStatus = AdminMonitoringStatus.connecting,
    this.realtimeError,
  });

  final List<MonitoredBus> buses;
  final AdminMonitoringStatus realtimeStatus;
  final String? realtimeError;

  bool get isEmpty => buses.isEmpty;

  AdminLiveMonitoringSnapshot copyWith({
    List<MonitoredBus>? buses,
    AdminMonitoringStatus? realtimeStatus,
    String? realtimeError,
    bool clearRealtimeError = false,
  }) {
    return AdminLiveMonitoringSnapshot(
      buses: buses ?? this.buses,
      realtimeStatus: realtimeStatus ?? this.realtimeStatus,
      realtimeError:
          clearRealtimeError ? null : realtimeError ?? this.realtimeError,
    );
  }
}

/// A single active bus being monitored — one per active trip.
class MonitoredBus {
  const MonitoredBus({
    required this.tripId,
    required this.busId,
    required this.busNumber,
    required this.busName,
    required this.routeId,
    required this.routeName,
    required this.driverName,
    required this.tripStatus,
    required this.tripStartedAt,
    this.location,
  });

  final String tripId;
  final String busId;
  final String busNumber;
  final String busName;
  final String routeId;
  final String routeName;

  /// Driver full name only — CNIC is never included.
  final String driverName;
  final String tripStatus;
  final DateTime tripStartedAt;
  final MonitoredBusLocation? location;

  bool get hasValidLocation => location?.isValid ?? false;

  bool get isStale {
    final recordedAt = location?.recordedAt;
    return recordedAt == null ||
        DateTime.now().difference(recordedAt).inMinutes >= 5;
  }

  MonitoredBus withLocation(MonitoredBusLocation? newLocation) {
    return MonitoredBus(
      tripId: tripId,
      busId: busId,
      busNumber: busNumber,
      busName: busName,
      routeId: routeId,
      routeName: routeName,
      driverName: driverName,
      tripStatus: tripStatus,
      tripStartedAt: tripStartedAt,
      location: newLocation ?? location,
    );
  }
}

/// GPS location for a monitored bus.
class MonitoredBusLocation {
  const MonitoredBusLocation({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.speed,
    this.heading,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? speed;
  final double? heading;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
