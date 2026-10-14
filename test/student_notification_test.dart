import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/student/data/student_arrival_notification_monitor.dart';
import 'package:muet_smart_bus_tracking_system/features/student/data/student_notification_service.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_live_tracking.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_route.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_stop_selection.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_stop_selection_repository.dart';

void main() {
  const stop = StudentRouteStop(
    id: 'stop-id',
    name: 'Main Gate',
    stopOrder: 1,
    latitude: 24.8608,
    longitude: 67.0011,
  );
  final tracking = StudentLiveTracking(
    tripId: 'trip-id',
    busId: 'bus-id',
    routeId: 'route-id',
    busNumber: 'B-01',
    busName: 'Campus Shuttle',
    busStatus: 'active',
    routeName: 'Main Route',
    tripStatus: 'active',
    tripStartedAt: DateTime.now(),
    location: StudentBusLocation(
      latitude: 24.8607,
      longitude: 67.0011,
      recordedAt: DateTime.now(),
      speedMetersPerSecond: 8,
    ),
  );

  test(
    'does not notify disabled alerts and deduplicates one trip event',
    () async {
      final gateway = _FakeNotificationGateway();
      final repository = _FakeSelectionRepository();
      final monitor = StudentArrivalNotificationMonitor(
        notificationService: gateway,
        selectionRepository: repository,
      );
      const selection = StudentStopSelection(
        id: 'alert-id',
        stopId: 'stop-id',
        busId: 'bus-id',
        radiusMeters: 500,
        enabled: true,
      );

      expect(
        await monitor.handleTrackingUpdate(
          profileId: 'profile-id',
          selection: selection,
          stop: stop,
          tracking: tracking,
        ),
        isTrue,
      );
      expect(
        await monitor.handleTrackingUpdate(
          profileId: 'profile-id',
          selection: selection,
          stop: stop,
          tracking: tracking,
        ),
        isFalse,
      );
      expect(gateway.calls, 1);
      expect(repository.marked, 1);

      const disabled = StudentStopSelection(
        id: 'disabled-alert-id',
        stopId: 'stop-id',
        busId: 'bus-id',
        radiusMeters: 500,
        enabled: false,
      );
      expect(
        await monitor.handleTrackingUpdate(
          profileId: 'profile-id',
          selection: disabled,
          stop: stop,
          tracking: tracking,
        ),
        isFalse,
      );
      expect(gateway.calls, 1);
    },
  );
}

class _FakeNotificationGateway implements StudentNotificationGateway {
  var calls = 0;

  @override
  Future<bool> showBusArrival({
    required String eventKey,
    required String busNumber,
    required String stopName,
  }) async {
    calls++;
    return true;
  }
}

class _FakeSelectionRepository implements StudentStopSelectionRepository {
  var marked = 0;

  @override
  Future<List<StudentStopSelection>> loadForStudent(String profileId) async =>
      const [];

  @override
  Future<StudentStopSelection> save({
    required String profileId,
    required String stopId,
    required String busId,
    required double radiusMeters,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> remove({
    required String profileId,
    required String selectionId,
  }) async {}

  @override
  Future<void> markTriggered({
    required String profileId,
    required String selectionId,
  }) async {
    marked++;
  }

  @override
  Future<void> setEnabled({
    required String profileId,
    required String selectionId,
    required bool enabled,
  }) async {}
}
