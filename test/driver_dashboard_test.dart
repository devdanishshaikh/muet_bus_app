import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/authenticated_user.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/user_role.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/presentation/pages/unauthorized_page.dart';
import 'package:muet_smart_bus_tracking_system/features/driver/domain/driver_dashboard_data.dart';
import 'package:muet_smart_bus_tracking_system/features/driver/domain/driver_dashboard_repository.dart';
import 'package:muet_smart_bus_tracking_system/features/driver/domain/driver_location_publisher.dart';
import 'package:muet_smart_bus_tracking_system/features/driver/domain/driver_location_state.dart';
import 'package:muet_smart_bus_tracking_system/features/driver/presentation/driver_dashboard_page.dart';
import 'package:muet_smart_bus_tracking_system/features/driver/presentation/driver_dashboard_providers.dart';
import 'package:muet_smart_bus_tracking_system/features/driver/presentation/driver_location_providers.dart';

void main() {
  const driver = AuthenticatedUser(
    id: 'driver-profile-id',
    email: 'driver@muet.edu.pk',
    fullName: 'MUET Driver',
    role: UserRole.driver,
    profileComplete: true,
  );
  const assignment = DriverAssignment(
    busId: 'bus-id',
    busNumber: 'B-01',
    busName: 'Campus Shuttle',
    busStatus: 'active',
    routeId: 'route-id',
    routeName: 'Main Route',
    routeDescription: 'Campus route',
    routeStatus: 'active',
    isActive: true,
  );

  testWidgets('shows assignment and allows starting a valid trip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverDashboardRepositoryProvider.overrideWithValue(
            const _FakeDriverDashboardRepository(
              DriverDashboardData(
                driverId: 'driver-id',
                driverName: 'MUET Driver',
                driverStatus: 'active',
                assignment: assignment,
              ),
            ),
          ),
          driverDashboardActionLoadingProvider.overrideWith(
            (ref, profileId) => false,
          ),
          driverLocationPublisherProvider.overrideWithValue(
            const _FakeDriverLocationPublisher(),
          ),
        ],
        child: const MaterialApp(home: DriverDashboardPage(user: driver)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome, MUET Driver'), findsOneWidget);
    expect(find.text('B-01 • Campus Shuttle'), findsOneWidget);
    expect(find.text('Route: Main Route'), findsOneWidget);
    expect(find.text('Start trip'), findsOneWidget);
  });

  testWidgets('shows driver profile card with name, email, and status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverDashboardRepositoryProvider.overrideWithValue(
            const _FakeDriverDashboardRepository(
              DriverDashboardData(
                driverId: 'driver-id',
                driverName: 'MUET Driver',
                driverStatus: 'active',
                assignment: assignment,
              ),
            ),
          ),
          driverLocationPublisherProvider.overrideWithValue(
            const _FakeDriverLocationPublisher(),
          ),
        ],
        child: const MaterialApp(home: DriverDashboardPage(user: driver)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MUET Driver'), findsWidgets);
    expect(find.text('driver@muet.edu.pk'), findsOneWidget);
    expect(find.text('Driver status: active'), findsOneWidget);
  });

  testWidgets('shows end trip for an own active trip', (
    WidgetTester tester,
  ) async {
    final trip = DriverTrip(
      id: 'trip-id',
      status: 'active',
      startedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverDashboardRepositoryProvider.overrideWithValue(
            _FakeDriverDashboardRepository(
              DriverDashboardData(
                driverId: 'driver-id',
                driverName: 'MUET Driver',
                driverStatus: 'active',
                assignment: assignment,
                activeTrip: trip,
              ),
            ),
          ),
          driverLocationPublisherProvider.overrideWithValue(
            const _FakeDriverLocationPublisher(),
          ),
        ],
        child: const MaterialApp(home: DriverDashboardPage(user: driver)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trip status: active'), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const Key('end-trip-button')),
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    expect(find.text('End trip'), findsOneWidget);
    expect(find.text('Start trip'), findsNothing);
  });

  testWidgets('shows confirmation dialog before ending trip', (
    WidgetTester tester,
  ) async {
    final trip = DriverTrip(
      id: 'trip-id',
      status: 'active',
      startedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverDashboardRepositoryProvider.overrideWithValue(
            _FakeDriverDashboardRepository(
              DriverDashboardData(
                driverId: 'driver-id',
                driverName: 'MUET Driver',
                driverStatus: 'active',
                assignment: assignment,
                activeTrip: trip,
              ),
            ),
          ),
          driverLocationPublisherProvider.overrideWithValue(
            const _FakeDriverLocationPublisher(),
          ),
        ],
        child: const MaterialApp(home: DriverDashboardPage(user: driver)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const Key('end-trip-button')),
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.tap(find.byKey(const Key('end-trip-button')));
    await tester.pumpAndSettle();

    expect(find.text('End trip?'), findsOneWidget);
    expect(find.text('Are you sure you want to end this trip? This action cannot be undone.'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('protects the dashboard from students', (
    WidgetTester tester,
  ) async {
    const student = AuthenticatedUser(
      id: 'student-id',
      email: 'student@muet.edu.pk',
      fullName: 'Student',
      role: UserRole.student,
      profileComplete: true,
    );

    await tester.pumpWidget(
      const MaterialApp(home: DriverDashboardPage(user: student)),
    );

    expect(find.byType(UnauthorizedPage), findsOneWidget);
  });

  testWidgets('shows unassigned state when no assignment exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverDashboardRepositoryProvider.overrideWithValue(
            const _FakeDriverDashboardRepository(
              DriverDashboardData(
                driverId: 'driver-id',
                driverName: 'MUET Driver',
                driverStatus: 'active',
              ),
            ),
          ),
          driverLocationPublisherProvider.overrideWithValue(
            const _FakeDriverLocationPublisher(),
          ),
        ],
        child: const MaterialApp(home: DriverDashboardPage(user: driver)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active assignment'), findsOneWidget);
    expect(find.text('Start trip'), findsOneWidget);
  });
}

class _FakeDriverDashboardRepository implements DriverDashboardRepository {
  const _FakeDriverDashboardRepository(this.data);

  final DriverDashboardData data;

  @override
  Future<DriverDashboardData?> load(String profileId) async => data;

  @override
  Future<DriverTrip> startTrip({
    required String profileId,
    required DriverAssignment assignment,
  }) async {
    return DriverTrip(
      id: 'trip-id',
      status: 'active',
      startedAt: DateTime.now(),
    );
  }

  @override
  Future<DriverTrip> endTrip({
    required String profileId,
    required String tripId,
  }) async {
    return DriverTrip(
      id: tripId,
      status: 'completed',
      startedAt: DateTime.now(),
      endedAt: DateTime.now(),
    );
  }
}

class _FakeDriverLocationPublisher implements DriverLocationPublisher {
  const _FakeDriverLocationPublisher();

  @override
  Stream<DriverLocationState> get states =>
      Stream.value(const DriverLocationState.idle());

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> start({required String tripId}) async {}

  @override
  Future<void> stop() async {}
}