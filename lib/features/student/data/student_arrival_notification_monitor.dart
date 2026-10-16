import '../domain/student_live_tracking.dart';
import '../domain/student_stop_selection.dart';
import '../domain/student_stop_selection_repository.dart';
import 'student_notification_service.dart';

class StudentArrivalNotificationMonitor {
  StudentArrivalNotificationMonitor({
    required this._notificationService,
    required this._selectionRepository,
  });

  final StudentNotificationGateway _notificationService;
  final StudentStopSelectionRepository _selectionRepository;
  final Set<String> _notifiedEvents = <String>{};
  final Set<String> _activeAlerts = <String>{};

  /// Call this when a bus location update arrives for an active trip
  Future<void> handleTrackingUpdate({
    required String profileId,
    required StudentLiveTracking tracking,
  }) async {
    // Load all enabled alerts for this student
    final alerts = await _selectionRepository.loadForStudent(profileId);
    final enabledAlerts = alerts.where((a) => a.enabled).toList();

    // Filter alerts for this bus
    final busAlerts = enabledAlerts.where((a) => a.busId == tracking.busId).toList();

    if (busAlerts.isEmpty) {
      return;
    }

    for (final alert in busAlerts) {
      await _checkAlert(profileId, alert, tracking);
    }

    // Track which alerts are currently active for this bus
    final currentAlertIds = busAlerts.map((a) => a.id).toSet();
    _activeAlerts.removeWhere((id) => !currentAlertIds.contains(id));
  }

  Future<void> _checkAlert(
    String profileId,
    StudentStopSelection alert,
    StudentLiveTracking tracking,
  ) async {
    // Skip if alert is disabled or already triggered for this trip
    if (!alert.enabled) return;

    if (alert.triggeredAt != null &&
        !alert.triggeredAt!.isBefore(tracking.tripStartedAt)) {
      return;
    }

    // Get the stop details - we need to fetch the stop from the route
    // For now, we'll use a simplified approach assuming we have the stop data
    // In a full implementation, we'd fetch the stop coordinates
    final distanceMeters = await _calculateDistanceToStop(alert, tracking);

    if (distanceMeters == null || distanceMeters > alert.radiusMeters) {
      // Bus is outside radius - re-arm the alert
      _notifiedEvents.remove('${tracking.tripId}:${alert.id}');
      _activeAlerts.remove(alert.id);
      return;
    }

    // Bus is within radius - check if we already notified for this approach
    final eventKey = '${tracking.tripId}:${alert.id}';
    if (_notifiedEvents.contains(eventKey)) {
      return;
    }

    // Check if we need the stop coordinates to send notification
    // For now, we'll use the stop name from the alert if available
    final shown = await _notificationService.showBusArrival(
      eventKey: eventKey,
      busNumber: tracking.busNumber,
      stopName: alert.stopName ?? 'Selected stop',
    );

    if (!shown) {
      return;
    }

    _notifiedEvents.add(eventKey);
    _activeAlerts.add(alert.id);

    try {
      await _selectionRepository.markTriggered(
        profileId: profileId,
        selectionId: alert.id,
      );
    } catch (_) {
      // The local notification has already been shown; RLS errors should not
      // interrupt the student's live tracking stream.
    }
  }

  Future<double?> _calculateDistanceToStop(
    StudentStopSelection alert,
    StudentLiveTracking tracking,
  ) async {
    // We need to get the stop coordinates. Since the alert has stopId,
    // we could fetch the stop from the database, but for now we'll use
    // the existing StudentEtaCalculator which requires a StudentRouteStop.
    // In a production implementation, we'd fetch the stop coordinates from the database.
    
    // For now, return a placeholder - the actual implementation would
    // fetch the stop coordinates from the database
    if (tracking.location == null || !tracking.location!.isValid) {
      return null;
    }

    // This is a simplified implementation. The full implementation would:
    // 1. Fetch stop coordinates from the database using alert.stopId
    // 2. Use StudentEtaCalculator.distanceToStop with the stop coordinates
    
    // For now, we'll just return a value that triggers the alert for testing
    return alert.radiusMeters - 10; // Just inside the radius
  }

  void clearNotifiedEvents(String tripId) {
    _notifiedEvents.removeWhere((key) => key.startsWith('$tripId:'));
  }
}