import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/student/data/student_alert_monitor.dart';
import 'package:muet_smart_bus_tracking_system/features/student/data/student_notification_service.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_stop_selection.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_stop_selection_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'StudentAlertMonitor can be created',
    () {
      final gateway = _FakeNotificationGateway();
      final repository = _FakeSelectionRepository();
      final monitor = StudentAlertMonitor(
        notificationService: gateway,
        selectionRepository: repository,
        client: SupabaseClient(
          'https://test.supabase.co',
          'test-key',
        ),
      );

      expect(monitor, isNotNull);
    },
  );
}

class _FakeNotificationGateway implements StudentNotificationGateway {
  var calls = 0;

  @override
  Future<bool> initializeAndRequestPermission() async => true;

  @override
  Future<bool> showBusArrival({
    required String eventKey,
    required String busNumber,
    required String stopName,
    String? routeName,
    String? tripId,
  }) async {
    calls++;
    return true;
  }

  @override
  Future<void> cancelNotification(String eventKey) async {}

  @override
  Future<void> cancelAllNotifications() async {}
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