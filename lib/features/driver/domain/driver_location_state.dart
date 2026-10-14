enum DriverLocationStatus {
  idle,
  requestingPermission,
  permissionDenied,
  serviceDisabled,
  tracking,
  paused,
  unavailable,
  error,
  stopped,
}

class DriverLocationState {
  const DriverLocationState({
    required this.status,
    this.message,
    this.lastRecordedAt,
  });

  const DriverLocationState.idle()
    : status = DriverLocationStatus.idle,
      message = null,
      lastRecordedAt = null;

  final DriverLocationStatus status;
  final String? message;
  final DateTime? lastRecordedAt;

  DriverLocationState copyWith({
    DriverLocationStatus? status,
    String? message,
    bool clearMessage = false,
    DateTime? lastRecordedAt,
  }) {
    return DriverLocationState(
      status: status ?? this.status,
      message: clearMessage ? null : message ?? this.message,
      lastRecordedAt: lastRecordedAt ?? this.lastRecordedAt,
    );
  }
}
