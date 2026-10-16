import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/domain/admin_dashboard_data.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/domain/admin_dashboard_repository.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/domain/admin_live_monitoring_data.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/presentation/admin_dashboard_page.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/presentation/admin_dashboard_providers.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/authenticated_user.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/user_role.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/presentation/pages/unauthorized_page.dart';

const _admin = AuthenticatedUser(
  id: 'admin-id',
  email: 'admin@muet.edu.pk',
  fullName: 'MUET Admin',
  role: UserRole.admin,
  profileComplete: true,
);

void main() {
  testWidgets('shows the transport overview and admin placeholders', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _dashboardApp(
        const _FakeAdminDashboardRepository(
          AdminDashboardData(
            totalBuses: 12,
            activeBuses: 8,
            totalDrivers: 10,
            activeDriverAssignments: 7,
            totalRoutes: 5,
            activeRoutes: 4,
            activeTrips: 3,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Transport overview'), findsOneWidget);
    expect(find.text('Total buses'), findsOneWidget);
    expect(find.text('Active trips'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Bus Management'), 200);
    expect(find.text('Bus Management'), findsOneWidget);
    expect(find.text('Driver Management'), findsOneWidget);
    expect(find.text('Route Management'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Live Monitoring'), 200);
    expect(find.text('Bus Assignments'), findsOneWidget);
    expect(find.text('Route Assignments'), findsOneWidget);
    expect(find.text('Live Monitoring'), findsOneWidget);
  });

  testWidgets('shows an empty state for an empty transport overview', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _dashboardApp(
        const _FakeAdminDashboardRepository(
          AdminDashboardData(
            totalBuses: 0,
            activeBuses: 0,
            totalDrivers: 0,
            activeDriverAssignments: 0,
            totalRoutes: 0,
            activeRoutes: 0,
            activeTrips: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No transport data is available yet.'), findsOneWidget);
  });

  testWidgets('shows a loading state while the overview loads', (
    WidgetTester tester,
  ) async {
    final completer = Completer<AdminDashboardData>();
    await tester.pumpWidget(
      _dashboardApp(_PendingAdminDashboardRepository(completer)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an error state when the overview cannot load', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_dashboardApp(const _FailingAdminDashboardRepository()));
    await tester.pumpAndSettle();

    expect(find.text('We could not load the transport overview.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('protects the dashboard from non-admin users', (
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
      const MaterialApp(home: AdminDashboardPage(user: student)),
    );

    expect(find.byType(UnauthorizedPage), findsOneWidget);
  });
}

Widget _dashboardApp(AdminDashboardRepository repository) {
  return ProviderScope(
    overrides: [
      adminDashboardRepositoryProvider.overrideWithValue(repository),
    ],
    child: const MaterialApp(home: AdminDashboardPage(user: _admin)),
  );
}

class _FakeAdminDashboardRepository implements AdminDashboardRepository {
  const _FakeAdminDashboardRepository(this.data);

  final AdminDashboardData data;

  @override
  Future<AdminDashboardData> load() async => data;

  @override
  Future<List<MonitoredBus>> loadActiveTrips() async => const [];
}

class _FailingAdminDashboardRepository implements AdminDashboardRepository {
  const _FailingAdminDashboardRepository();

  @override
  Future<AdminDashboardData> load() async {
    throw Exception('Unable to load overview');
  }

  @override
  Future<List<MonitoredBus>> loadActiveTrips() async => const [];
}

class _PendingAdminDashboardRepository implements AdminDashboardRepository {
  const _PendingAdminDashboardRepository(this.completer);

  final Completer<AdminDashboardData> completer;

  @override
  Future<AdminDashboardData> load() => completer.future;

  @override
  Future<List<MonitoredBus>> loadActiveTrips() async => const [];
}
