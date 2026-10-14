import '../domain/student_eta.dart';
import '../domain/student_live_tracking.dart';
import '../domain/student_route.dart';
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

  Future<bool> handleTrackingUpdate({
    required String profileId,
    required StudentStopSelection selection,
    required StudentRouteStop stop,
    required StudentLiveTracking tracking,
  }) async {
    if (!selection.enabled ||
        (selection.triggeredAt != null &&
            !selection.triggeredAt!.isBefore(tracking.tripStartedAt))) {
      return false;
    }
    final distanceMeters = StudentEtaCalculator.distanceToStop(
      location: tracking.location,
      stop: stop,
    );
    if (distanceMeters == null || distanceMeters > selection.radiusMeters) {
      return false;
    }

    final eventKey = '${tracking.tripId}:${selection.id}';
    if (_notifiedEvents.contains(eventKey)) {
      return false;
    }

    final shown = await _notificationService.showBusArrival(
      eventKey: eventKey,
      busNumber: tracking.busNumber,
      stopName: stop.name,
    );
    if (!shown) {
      return false;
    }

    _notifiedEvents.add(eventKey);
    try {
      await _selectionRepository.markTriggered(
        profileId: profileId,
        selectionId: selection.id,
      );
    } catch (_) {
      // The local notification has already been shown; RLS errors should not
      // interrupt the student's live tracking stream.
    }
    return true;
  }
}
