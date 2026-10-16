import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/authenticated_user.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/user_role.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_route.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_routes_repository.dart';
import 'package:muet_smart_bus_tracking_system/features/student/presentation/student_route_details_page.dart';
import 'package:muet_smart_bus_tracking_system/features/student/presentation/student_routes_page.dart';
import 'package:muet_smart_bus_tracking_system/features/student/presentation/student_routes_providers.dart';

void main() {
  const student = AuthenticatedUser(
    id: 'student-profile-id',
    email: 'student@muet.edu.pk',
    fullName: 'MUET Student',
    role: UserRole.student,
    profileComplete: true,
  );
  const route = StudentRoute(
    id: 'route-id',
    name: 'Main Campus Route',
    description: 'Campus to hostel route',
    status: 'active',
    stops: [
      StudentRouteStop(id: 'stop-1', name: 'Main Gate', stopOrder: 1),
      StudentRouteStop(id: 'stop-2', name: 'Hostel Block', stopOrder: 2),
    ],
  );

  testWidgets('shows active routes and opens route details', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentRoutesRepositoryProvider.overrideWithValue(
            const _FakeStudentRoutesRepository(
              routes: [route],
              details: StudentRouteDetails(
                route: route,
                activeBus: ActiveRouteBus(
                  busNumber: 'B-01',
                  busName: 'Campus Shuttle',
                  status: 'active',
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: StudentRoutesPage(user: student)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Main Campus Route'), findsOneWidget);
    expect(find.text('Campus to hostel route'), findsOneWidget);

    await tester.tap(find.text('Main Campus Route'));
    await tester.pumpAndSettle();

    expect(find.byType(StudentRouteDetailsPage), findsOneWidget);
    expect(find.text('Main Gate'), findsOneWidget);
    expect(find.text('Hostel Block'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('B-01 • Campus Shuttle'), findsOneWidget);
  });

  testWidgets('shows a clear empty route state', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentRoutesRepositoryProvider.overrideWithValue(
            const _FakeStudentRoutesRepository(routes: []),
          ),
        ],
        child: const MaterialApp(home: StudentRoutesPage(user: student)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No active routes are available right now.'),
      findsOneWidget,
    );
  });
}

class _FakeStudentRoutesRepository implements StudentRoutesRepository {
  const _FakeStudentRoutesRepository({required this.routes, this.details});

  final List<StudentRoute> routes;
  final StudentRouteDetails? details;

  @override
  Future<List<StudentRoute>> loadRoutes() async => routes;

  @override
  Future<StudentRouteDetails?> loadRouteDetails(String routeId) async =>
      details;

  @override
  Future<List<StudentRouteDetails>> loadRoutesWithActiveBuses() async => [];
}