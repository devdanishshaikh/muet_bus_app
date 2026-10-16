import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/student_eta.dart';
import '../domain/student_live_tracking.dart';
import '../domain/student_route.dart';
import '../domain/student_stop_selection.dart';
import '../domain/student_stop_selection_repository.dart';
import 'student_notification_service.dart';

class StudentAlertMonitor {
  StudentAlertMonitor({
    required this._notificationService,
    required this._selectionRepository,
    required this._client,
  });

  final StudentNotificationGateway _notificationService;
  final StudentStopSelectionRepository _selectionRepository;
  final SupabaseClient _client;

  final Set<String> _notifiedEvents = <String>{};
  final Map<String, Set<String>> _tripActiveAlerts = <String, Set<String>>{};

  /// Process a bus location update and check all relevant alerts
  Future<void> processLocationUpdate({
    required String profileId,
    required StudentLiveTracking tracking,
  }) async {
    // Only process if the bus has a valid location
    if (tracking.location == null || !tracking.location!.isValid) {
      return;
    }

    // Load all enabled alerts for this student
    final alerts = await _selectionRepository.loadForStudent(profileId);
    final enabledAlerts = alerts.where((a) => a.enabled).toList();

    // Filter alerts for this specific bus
    final busAlerts = enabledAlerts.where((a) => a.busId == tracking.busId).toList();

    if (busAlerts.isEmpty) {
      return;
    }

    for (final alert in busAlerts) {
      await _checkAndTriggerAlert(profileId, alert, tracking);
    }

    // Track active alerts for this trip
    _tripActiveAlerts[tracking.tripId] = busAlerts.map((a) => a.id).toSet();
  }

  Future<void> _checkAndTriggerAlert(
    String profileId,
    StudentStopSelection alert,
    StudentLiveTracking tracking,
  ) async {
    // Skip if alert is disabled
    if (!alert.enabled) return;

    // Skip if already triggered for this trip
    if (alert.triggeredAt != null &&
        !alert.triggeredAt!.isBefore(tracking.tripStartedAt)) {
      return;
    }

    // Calculate distance to stop
    final distanceMeters = await _calculateDistanceToStop(alert, tracking);

    if (distanceMeters == null || distanceMeters > alert.radiusMeters) {
      // Bus is outside radius - re-arm the alert for this trip
      _notifiedEvents.remove('${tracking.tripId}:${alert.id}');
      return;
    }

    // Bus is within radius - check if we already notified for this trip
    final eventKey = '${tracking.tripId}:${alert.id}';
    if (_notifiedEvents.contains(eventKey)) {
      return;
    }

    // Trigger the alert
    final shown = await _notificationService.showBusArrival(
      eventKey: eventKey,
      busNumber: tracking.busNumber,
      stopName: alert.stopName ?? 'Selected stop',
      routeName: alert.routeName,
      tripId: tracking.tripId,
    );

    if (!shown) {
      return;
    }

    _notifiedEvents.add(eventKey);

    try {
      await _selectionRepository.markTriggered(
        profileId: profileId,
        selectionId: alert.id,
      );
      // Invalidate the alerts provider to refresh UI
    } catch (_) {
      // Notification was shown; RLS errors should not interrupt the stream
    }
  }

  Future<double?> _calculateDistanceToStop(
    StudentStopSelection alert,
    StudentLiveTracking tracking,
  ) async {
    // Fetch stop coordinates from database
    final stop = await _client
        .from('stops')
        .select('latitude, longitude')
        .eq('id', alert.stopId)
        .maybeSingle();

    if (stop == null) return null;

    final stopLatitude = double.tryParse(stop['latitude'].toString());
    final stopLongitude = double.tryParse(stop['longitude'].toString());

    if (stopLatitude == null || stopLongitude == null) return null;

    final location = tracking.location!;
    if (!location.isValid) return null;

    // Use the existing haversine distance calculation
    return StudentEtaCalculator.distanceToStop(
      location: location,
      stop: StudentRouteStop(
        id: alert.stopId,
        name: alert.stopName ?? '',
        stopOrder: 0,
        latitude: stopLatitude,
        longitude: stopLongitude,
      ),
    );
  }

  void clearTripNotifications(String tripId) {
    _notifiedEvents.removeWhere((key) => key.startsWith('$tripId:'));
    _tripActiveAlerts.remove(tripId);
  }
}