enum StudentRealtimeStatus {
  connecting,
  connected,
  reconnecting,
  disconnected,
  error,
}

class StudentLiveTracking {
  const StudentLiveTracking({
    required this.tripId,
    required this.busId,
    required this.routeId,
    required this.busNumber,
    required this.busName,
    required this.busStatus,
    required this.routeName,
    required this.tripStatus,
    required this.tripStartedAt,
    this.location,
    this.realtimeError,
    this.realtimeStatus = StudentRealtimeStatus.connecting,
  });

  final String tripId;
  final String busId;
  final String routeId;
  final String busNumber;
  final String busName;
  final String busStatus;
  final String routeName;
  final String tripStatus;
  final DateTime tripStartedAt;
  final StudentBusLocation? location;
  final String? realtimeError;
  final StudentRealtimeStatus realtimeStatus;

  bool get hasValidLocation => location?.isValid ?? false;

  bool get isStale {
    final recordedAt = location?.recordedAt;
    return recordedAt == null ||
        DateTime.now().difference(recordedAt).inMinutes >= 5;
  }

  StudentLiveTracking copyWith({
    StudentBusLocation? location,
    String? realtimeError,
    bool clearRealtimeError = false,
    StudentRealtimeStatus? realtimeStatus,
  }) {
    return StudentLiveTracking(
      tripId: tripId,
      busId: busId,
      routeId: routeId,
      busNumber: busNumber,
      busName: busName,
      busStatus: busStatus,
      routeName: routeName,
      tripStatus: tripStatus,
      tripStartedAt: tripStartedAt,
      location: location ?? this.location,
      realtimeError: clearRealtimeError
          ? null
          : realtimeError ?? this.realtimeError,
      realtimeStatus: realtimeStatus ?? this.realtimeStatus,
    );
  }
}

class StudentBusLocation {
  const StudentBusLocation({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.speedMetersPerSecond,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? speedMetersPerSecond;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
