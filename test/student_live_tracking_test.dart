import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/authenticated_user.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/user_role.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/presentation/pages/unauthorized_page.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_live_tracking.dart';
import 'package:muet_smart_bus_tracking_system/features/student/presentation/student_live_tracking_page.dart';

void main() {
  testWidgets('shows configuration state without a Maps key', (
    WidgetTester tester,
  ) async {
    const user = AuthenticatedUser(
      id: 'student-id',
      email: 'student@muet.edu.pk',
      fullName: 'Student',
      role: UserRole.student,
      profileComplete: true,
    );

    await tester.pumpWidget(
      const MaterialApp(home: StudentLiveTrackingPage(user: user)),
    );

    expect(
      find.text('Live tracking is not configured for this build.'),
      findsOneWidget,
    );
  });

  testWidgets('protects tracking from non-student roles', (
    WidgetTester tester,
  ) async {
    const user = AuthenticatedUser(
      id: 'driver-id',
      email: 'driver@muet.edu.pk',
      fullName: 'Driver',
      role: UserRole.driver,
      profileComplete: true,
    );

    await tester.pumpWidget(
      const MaterialApp(home: StudentLiveTrackingPage(user: user)),
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
}
