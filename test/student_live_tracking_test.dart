import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/authenticated_user.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/user_role.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/presentation/pages/unauthorized_page.dart';
import 'package:muet_smart_bus_tracking_system/features/student/data/student_notification_service.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_live_tracking.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_live_tracking_repository.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_stop_selection.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_stop_selection_repository.dart';
import 'package:muet_smart_bus_tracking_system/features/student/presentation/student_live_tracking_page.dart';
import 'package:muet_smart_bus_tracking_system/features/student/presentation/student_live_tracking_providers.dart';
import 'package:muet_smart_bus_tracking_system/features/student/presentation/student_notification_providers.dart';
import 'package:muet_smart_bus_tracking_system/features/student/presentation/student_stop_selection_providers.dart';

void main() {
  const student = AuthenticatedUser(
    id: 'student-id',
    email: 'student@muet.edu.pk',
    fullName: 'Student',
    role: UserRole.student,
    profileComplete: true,
  );
  const driver = AuthenticatedUser(
    id: 'driver-id',
    email: 'driver@muet.edu.pk',
    fullName: 'Driver',
    role: UserRole.driver,
    profileComplete: true,
  );

  final fakeRepo = _FakeStudentStopSelectionRepository();
  final fakeNotificationService = _FakeStudentNotificationService();
  final fakeTrackingRepo = _FakeStudentLiveTrackingRepository();

  testWidgets('shows configuration state without a Maps key', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentLiveTrackingRepositoryProvider.overrideWithValue(fakeTrackingRepo),
          studentNotificationServiceProvider.overrideWithValue(fakeNotificationService),
          studentStopSelectionRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(home: StudentLiveTrackingPage(user: student)),
      ),
    );

    expect(
      find.text('Live tracking is not configured for this build.'),
      findsOneWidget,
    );
  });

  testWidgets('protects tracking from non-student roles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: const MaterialApp(home: StudentLiveTrackingPage(user: driver)),
      ),
    );

    expect(find.byType(UnauthorizedPage), findsOneWidget);
  });

  test('rejects invalid coordinates and identifies stale locations', () {
    final invalid = StudentBusLocation(
      latitude: 91,
      longitude: 0,
      recordedAt: DateTime.now(),
    );
    final stale = StudentBusLocation(
      latitude: 24.86,
      longitude: 67.01,
      recordedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    );

    expect(invalid.isValid, isFalse);
    expect(stale.isValid, isTrue);

    final tracking = StudentLiveTracking(
      tripId: 'trip-id',
      busId: 'bus-id',
      routeId: 'route-id',
      busNumber: 'B-01',
      busName: 'Campus Shuttle',
      busStatus: 'active',
      routeName: 'Main Campus Route',
      tripStatus: 'active',
      tripStartedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      location: stale,
    );

    expect(tracking.hasValidLocation, isTrue);
    expect(tracking.isStale, isTrue);
    expect(tracking.realtimeStatus, StudentRealtimeStatus.connecting);
    expect(
      tracking
          .copyWith(
            realtimeStatus: StudentRealtimeStatus.reconnecting,
            realtimeError: 'Reconnecting',
          )
          .realtimeStatus,
      StudentRealtimeStatus.reconnecting,
    );
  });

  test('centerOf returns safe default when no valid locations exist', () {
    final buses = <StudentLiveTracking>[
      StudentLiveTracking(
        tripId: 'trip-1',
        busId: 'bus-1',
        routeId: 'route-1',
        busNumber: 'B-01',
        busName: 'Shuttle',
        busStatus: 'active',
        routeName: 'Campus',
        tripStatus: 'active',
        tripStartedAt: DateTime.now(),
        location: null,
      ),
    ];

    final state = _TestTrackingMapState();
    final center = state.centerOf(buses);

    expect(center.latitude, 24.8607);
    expect(center.longitude, 67.0011);
  });

  test('centerOf calculates average of valid locations', () {
    final buses = <StudentLiveTracking>[
      StudentLiveTracking(
        tripId: 'trip-1',
        busId: 'bus-1',
        routeId: 'route-1',
        busNumber: 'B-01',
        busName: 'Shuttle',
        busStatus: 'active',
        routeName: 'Campus',
        tripStatus: 'active',
        tripStartedAt: DateTime.now(),
        location: StudentBusLocation(
          latitude: 24.0,
          longitude: 67.0,
          recordedAt: DateTime.now(),
        ),
      ),
      StudentLiveTracking(
        tripId: 'trip-2',
        busId: 'bus-2',
        routeId: 'route-2',
        busNumber: 'B-02',
        busName: 'Shuttle 2',
        busStatus: 'active',
        routeName: 'Campus 2',
        tripStatus: 'active',
        tripStartedAt: DateTime.now(),
        location: StudentBusLocation(
          latitude: 26.0,
          longitude: 69.0,
          recordedAt: DateTime.now(),
        ),
      ),
    ];

    final state = _TestTrackingMapState();
    final center = state.centerOf(buses);

    expect(center.latitude, 25.0);
    expect(center.longitude, 68.0);
  });

  test('formatStatus capitalizes first letter', () {
    expect(_formatStatus('active'), 'Active');
    expect(_formatStatus(''), 'Unknown');
    expect(_formatStatus('  '), 'Unknown');
  });

  test('formatDateTime returns local time without milliseconds', () {
    final dt = DateTime(2026, 10, 14, 10, 30, 45, 123);
    final formatted = _formatDateTime(dt);
    expect(formatted.contains('.'), isFalse);
    expect(formatted.contains('2026'), isTrue);
  });
}

class _TestTrackingMapState {
  LatLng centerOf(List<StudentLiveTracking> buses) {
    var latitude = 0.0;
    var longitude = 0.0;
    var count = 0;
    for (final bus in buses) {
      final location = bus.location;
      if (location == null) {
        continue;
      }
      latitude += location.latitude;
      longitude += location.longitude;
      count++;
    }
    if (count == 0) {
      return const LatLng(24.8607, 67.0011);
    }
    return LatLng(latitude / count, longitude / count);
  }
}

String _formatDateTime(DateTime value) {
  return value.toLocal().toString().split('.').first;
}

String _formatStatus(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Unknown';
  }
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
}

class _FakeStudentLiveTrackingRepository implements StudentLiveTrackingRepository {
  @override
  Future<List<StudentLiveTracking>> loadActiveBuses() async => [];

  @override
  Future<StudentLiveTracking?> load({String? routeId, String? busId}) async => null;

  @override
  Stream<List<StudentLiveTracking>> watchActiveBuses() async* {
    yield [];
  }
}

class _FakeStudentStopSelectionRepository implements StudentStopSelectionRepository {
  @override
  Future<List<StudentStopSelection>> loadForStudent(String profileId) async => [];

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
  Future<void> remove({required String profileId, required String selectionId}) async {}

  @override
  Future<void> markTriggered({
    required String profileId,
    required String selectionId,
  }) async {}

  @override
  Future<void> setEnabled({
    required String profileId,
    required String selectionId,
    required bool enabled,
  }) async {}
}

class _FakeStudentNotificationService implements StudentNotificationService {
  @override
  Future<bool> initializeAndRequestPermission() async => false;

  @override
  Future<bool> showBusArrival({
    required String eventKey,
    required String busNumber,
    required String stopName,
    String? routeName,
    String? tripId,
  }) async => false;

  @override
  Future<void> cancelNotification(String eventKey) async {}

  @override
  Future<void> cancelAllNotifications() async {}

  @override
  bool? get permissionGranted => false;
}