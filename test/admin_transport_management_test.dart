import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/domain/admin_transport_management_data.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/domain/admin_transport_management_repository.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/presentation/admin_dashboard_providers.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/presentation/admin_transport_management_pages.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/authenticated_user.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/user_role.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/presentation/pages/unauthorized_page.dart';

const _admin = AuthenticatedUser(
  id: 'admin-id',
  email: 'admin@muet.edu.pk',
  fullName: 'Admin',
  role: UserRole.admin,
  profileComplete: true,
);

const _route = AdminRoute(
  id: 'route-1',
  name: 'Main Route',
  description: 'Campus route',
  status: 'active',
);

void main() {
  testWidgets('bus management shows a real bus record', (tester) async {
    await tester.pumpWidget(_app(const _FakeManagementRepository()));
    await tester.pumpAndSettle();

    expect(find.text('B-01'), findsOneWidget);
    expect(find.textContaining('Campus Shuttle'), findsOneWidget);
  });

  testWidgets('driver management shows safe fields without CNIC', (tester) async {
    await tester.pumpWidget(
      _app(const _FakeManagementRepository(), page: AdminDriverManagementPage(user: _admin)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Driver One'), findsOneWidget);
    expect(find.textContaining('0300-0000000'), findsOneWidget);
    expect(find.textContaining('CNIC'), findsNothing);
  });

  testWidgets('route management shows routes and stops screen shows ordered stops', (tester) async {
    await tester.pumpWidget(
      _app(const _FakeManagementRepository(), page: AdminRouteManagementPage(user: _admin)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Main Route'), findsOneWidget);

    await tester.tap(find.text('Main Route'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Main Gate'), findsOneWidget);
  });

  testWidgets('bus-driver assignments are displayed', (tester) async {
    await tester.pumpWidget(
      _app(const _FakeManagementRepository(), page: AdminBusDriverAssignmentsPage(user: _admin)),
    );
    await tester.pumpAndSettle();
    expect(find.text('B-01 - Driver One'), findsOneWidget);
  });

  testWidgets('bus-route assignments are displayed', (tester) async {
    await tester.pumpWidget(
      _app(const _FakeManagementRepository(), page: AdminBusRouteAssignmentsPage(user: _admin)),
    );
    await tester.pumpAndSettle();
    expect(find.text('B-01 - Main Route'), findsOneWidget);
  });

  testWidgets('route schedules are displayed', (tester) async {
    await tester.pumpWidget(
      _app(const _FakeManagementRepository(), page: AdminRouteSchedulesPage(user: _admin)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Main Route - Main Gate'), findsOneWidget);
    expect(find.text('Monday at 08:00:00'), findsOneWidget);
  });

  testWidgets('management screens show loading, empty, and error states', (tester) async {
    final pending = Completer<List<AdminBus>>();
    await tester.pumpWidget(_app(_PendingManagementRepository(pending)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(_app(const _EmptyManagementRepository()));
    await tester.pumpAndSettle();
    expect(find.text('No buses have been added yet.'), findsOneWidget);

    await tester.pumpWidget(_app(const _FailingManagementRepository()));
    await tester.pumpAndSettle();
    expect(find.text('We could not load this admin section.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('management screens protect non-admin users', (tester) async {
    const student = AuthenticatedUser(
      id: 'student-id',
      email: 'student@muet.edu.pk',
      fullName: 'Student',
      role: UserRole.student,
      profileComplete: true,
    );
    await tester.pumpWidget(
      const MaterialApp(home: AdminBusManagementPage(user: student)),
    );
    expect(find.byType(UnauthorizedPage), findsOneWidget);
  });
}

Widget _app(AdminTransportManagementRepository repository, {Widget? page}) {
  return ProviderScope(
    overrides: [
      adminTransportManagementRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(home: page ?? const AdminBusManagementPage(user: _admin)),
  );
}

class _FakeManagementRepository implements AdminTransportManagementRepository {
  const _FakeManagementRepository();

  @override
  Future<void> assignDriverToBus({required String busId, required String driverId}) async {}

  @override
  Future<void> assignRouteToBus({required String busId, required String routeId}) async {}

  @override
  Future<List<AdminBusDriverAssignment>> loadBusDriverAssignments() async => const [
    AdminBusDriverAssignment(id: 'ba-1', busId: 'bus-1', busName: 'B-01', driverId: 'driver-1', driverName: 'Driver One', active: true),
  ];

  @override
  Future<List<AdminBusRouteAssignment>> loadBusRouteAssignments() async => const [
    AdminBusRouteAssignment(id: 'ra-1', busId: 'bus-1', busName: 'B-01', routeId: 'route-1', routeName: 'Main Route', active: true),
  ];

  @override
  Future<List<AdminBus>> loadBuses() async => const [
    AdminBus(id: 'bus-1', busNumber: 'B-01', busName: 'Campus Shuttle', status: 'active'),
  ];

  @override
  Future<List<AdminDriver>> loadDrivers() async => const [
    AdminDriver(id: 'driver-1', name: 'Driver One', phone: '0300-0000000', status: 'active'),
  ];

  @override
  Future<List<AdminRoute>> loadRoutes() async => const [_route];

  @override
  Future<List<AdminRouteSchedule>> loadRouteSchedules() async => const [
    AdminRouteSchedule(id: 'schedule-1', routeId: 'route-1', routeName: 'Main Route', stopId: 'stop-1', stopName: 'Main Gate', dayOfWeek: 0, scheduledTime: '08:00:00'),
  ];

  @override
  Future<List<AdminStop>> loadStops(String routeId) async => const [
    AdminStop(id: 'stop-1', routeId: 'route-1', name: 'Main Gate', latitude: 25.396, longitude: 68.357, stopOrder: 1),
  ];

  @override
  Future<void> saveBus(AdminBus bus) async {}

  @override
  Future<void> saveRoute(AdminRoute route) async {}

  @override
  Future<void> saveRouteSchedule(AdminRouteSchedule schedule) async {}

  @override
  Future<void> saveStop(AdminStop stop) async {}

  @override
  Future<void> updateDriverStatus(String driverId, String status) async {}
}

class _EmptyManagementRepository extends _FakeManagementRepository {
  const _EmptyManagementRepository();

  @override
  Future<List<AdminBus>> loadBuses() async => const [];
}

class _FailingManagementRepository extends _FakeManagementRepository {
  const _FailingManagementRepository();

  @override
  Future<List<AdminBus>> loadBuses() async => throw Exception('load failed');
}

class _PendingManagementRepository extends _FakeManagementRepository {
  const _PendingManagementRepository(this.pending);
  final Completer<List<AdminBus>> pending;

  @override
  Future<List<AdminBus>> loadBuses() => pending.future;
}
