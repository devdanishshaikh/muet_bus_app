import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/domain/admin_live_monitoring_data.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/domain/admin_live_monitoring_repository.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/presentation/admin_live_monitoring_page.dart';
import 'package:muet_smart_bus_tracking_system/features/admin/presentation/admin_live_monitoring_providers.dart';
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

MonitoredBus _sampleBus({
  String tripId = 'trip-1',
  String busNumber = 'MU-01',
  String busName = 'University Express',
  String routeName = 'Route A',
  String driverName = 'Ahmed Khan',
  String tripStatus = 'active',
  MonitoredBusLocation? location,
}) {
  return MonitoredBus(
    tripId: tripId,
    busId: 'bus-1',
    busNumber: busNumber,
    busName: busName,
    routeId: 'route-1',
    routeName: routeName,
    driverName: driverName,
    tripStatus: tripStatus,
    tripStartedAt: DateTime(2026, 10, 3, 9, 0),
    location: location,
  );
}

void main() {
  group('AdminLiveMonitoringPage', () {
    testWidgets('shows active buses with their details', (tester) async {
      final bus = _sampleBus();
      await tester.pumpWidget(
        _monitoringApp(_FakeRepository(buses: [bus])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Monitoring'), findsOneWidget);
      expect(find.text('MU-01 • University Express'), findsOneWidget);
      expect(find.text('Route: Route A'), findsOneWidget);
      expect(find.text('Driver: Ahmed Khan'), findsOneWidget);
      expect(find.text('Trip status: active'), findsOneWidget);
    });

    testWidgets('shows empty state when no active trips', (tester) async {
      await tester.pumpWidget(
        _monitoringApp(const _FakeRepository(buses: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('No active trips at the moment.'), findsOneWidget);
    });

    testWidgets('shows loading state', (tester) async {
      final completer = Completer<List<MonitoredBus>>();
      await tester.pumpWidget(
        _monitoringApp(_PendingRepository(completer)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state when data fails to load', (tester) async {
      await tester.pumpWidget(
        _monitoringApp(const _FailingRepository()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('We could not load live monitoring data.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('protects the page from non-admin users', (tester) async {
      const student = AuthenticatedUser(
        id: 'student-id',
        email: 'student@muet.edu.pk',
        fullName: 'Student',
        role: UserRole.student,
        profileComplete: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminLiveMonitoringPage(user: student),
        ),
      );

      expect(find.byType(UnauthorizedPage), findsOneWidget);
    });

    testWidgets('protects the page from driver users', (tester) async {
      const driver = AuthenticatedUser(
        id: 'driver-id',
        email: 'driver@muet.edu.pk',
        fullName: 'Driver',
        role: UserRole.driver,
        profileComplete: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminLiveMonitoringPage(user: driver),
        ),
      );

      expect(find.byType(UnauthorizedPage), findsOneWidget);
    });

    testWidgets('shows stale label when location is old', (tester) async {
      final staleLoc = MonitoredBusLocation(
        latitude: 25.4,
        longitude: 68.3,
        recordedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      final bus = _sampleBus(location: staleLoc);
      await tester.pumpWidget(
        _monitoringApp(_FakeRepository(buses: [bus])),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('(stale)'), findsOneWidget);
    });

    testWidgets('shows "No data yet" when no location available', (
      tester,
    ) async {
      final bus = _sampleBus(); // no location
      await tester.pumpWidget(
        _monitoringApp(_FakeRepository(buses: [bus])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Last location: No data yet'), findsOneWidget);
    });
  });

  group('AdminLiveMonitoringData models', () {
    test('MonitoredBusLocation validates coordinates', () {
      final validLoc = MonitoredBusLocation(
        latitude: 25.39,
        longitude: 68.36,
        recordedAt: DateTime.now(),
      );
      expect(validLoc.isValid, isTrue);

      final invalidLoc = MonitoredBusLocation(
        latitude: 91.0,
        longitude: 68.36,
        recordedAt: DateTime.now(),
      );
      expect(invalidLoc.isValid, isFalse);
    });

    test('MonitoredBus.isStale returns true when no location', () {
      final bus = _sampleBus();
      expect(bus.isStale, isTrue);
    });

    test('MonitoredBus.isStale returns false for recent location', () {
      final bus = _sampleBus(
        location: MonitoredBusLocation(
          latitude: 25.39,
          longitude: 68.36,
          recordedAt: DateTime.now(),
        ),
      );
      expect(bus.isStale, isFalse);
    });

    test('MonitoredBus.isStale returns true for location older than 5min', () {
      final bus = _sampleBus(
        location: MonitoredBusLocation(
          latitude: 25.39,
          longitude: 68.36,
          recordedAt: DateTime.now().subtract(const Duration(minutes: 6)),
        ),
      );
      expect(bus.isStale, isTrue);
    });

    test('MonitoredBusLocation.isValid rejects out-of-range coordinates', () {
      final loc = MonitoredBusLocation(
        latitude: 100.0,
        longitude: 68.36,
        recordedAt: DateTime.now(),
      );
      expect(loc.isValid, isFalse);
    });

    test('AdminLiveMonitoringSnapshot.isEmpty is true for empty buses', () {
      const snapshot = AdminLiveMonitoringSnapshot(buses: []);
      expect(snapshot.isEmpty, isTrue);
    });

    test('AdminLiveMonitoringSnapshot.copyWith preserves fields', () {
      final snapshot = AdminLiveMonitoringSnapshot(
        buses: [_sampleBus()],
        realtimeStatus: AdminMonitoringStatus.connected,
      );
      final updated = snapshot.copyWith(
        realtimeStatus: AdminMonitoringStatus.reconnecting,
        realtimeError: 'network error',
      );
      expect(updated.realtimeStatus, AdminMonitoringStatus.reconnecting);
      expect(updated.realtimeError, 'network error');
      expect(updated.buses.length, 1);
    });

    test('MonitoredBus.withLocation returns new instance', () {
      final bus = _sampleBus();
      final loc = MonitoredBusLocation(
        latitude: 25.39,
        longitude: 68.36,
        recordedAt: DateTime.now(),
      );
      final updated = bus.withLocation(loc);
      expect(updated.location, loc);
      expect(updated.busNumber, bus.busNumber);
      expect(identical(updated, bus), isFalse);
    });
  });
}

Widget _monitoringApp(AdminLiveMonitoringRepository repository) {
  return ProviderScope(
    overrides: [
      adminLiveMonitoringRepositoryProvider.overrideWithValue(repository),
    ],
    child: const MaterialApp(
      home: AdminLiveMonitoringPage(user: _admin),
    ),
  );
}

class _FakeRepository implements AdminLiveMonitoringRepository {
  const _FakeRepository({required this.buses});

  final List<MonitoredBus> buses;

  @override
  Future<List<MonitoredBus>> loadActiveTrips() async => buses;

  @override
  Stream<AdminLiveMonitoringSnapshot> watchActiveTrips() async* {
    yield AdminLiveMonitoringSnapshot(
      buses: buses,
      realtimeStatus: AdminMonitoringStatus.connected,
    );
  }
}

class _FailingRepository implements AdminLiveMonitoringRepository {
  const _FailingRepository();

  @override
  Future<List<MonitoredBus>> loadActiveTrips() async {
    throw Exception('Unable to load monitoring data');
  }

  @override
  Stream<AdminLiveMonitoringSnapshot> watchActiveTrips() {
    return Stream.error(Exception('Unable to load monitoring data'));
  }
}

class _PendingRepository implements AdminLiveMonitoringRepository {
  const _PendingRepository(this.completer);

  final Completer<List<MonitoredBus>> completer;

  @override
  Future<List<MonitoredBus>> loadActiveTrips() => completer.future;

  @override
  Stream<AdminLiveMonitoringSnapshot> watchActiveTrips() async* {
    final buses = await completer.future;
    yield AdminLiveMonitoringSnapshot(buses: buses);
  }
}
