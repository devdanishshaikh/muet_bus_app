import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/authenticated_user.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/user_role.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/presentation/pages/unauthorized_page.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_dashboard_data.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_dashboard_repository.dart';
import 'package:muet_smart_bus_tracking_system/features/student/presentation/student_dashboard_page.dart';
import 'package:muet_smart_bus_tracking_system/features/student/presentation/student_dashboard_providers.dart';

void main() {
  const student = AuthenticatedUser(
    id: 'student-profile-id',
    email: 'student@muet.edu.pk',
    fullName: 'MUET Student',
    role: UserRole.student,
    profileComplete: true,
  );

  testWidgets('shows student identity and empty transport state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentDashboardRepositoryProvider.overrideWithValue(
            _FakeStudentDashboardRepository(
              const StudentDashboardData(studentId: 'ST-001'),
            ),
          ),
        ],
        child: const MaterialApp(home: StudentDashboardPage(user: student)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MUET Student'), findsOneWidget);
    expect(find.text('Student ID: ST-001'), findsOneWidget);
    expect(find.text('No active trip'), findsOneWidget);
    expect(find.text('View routes'), findsOneWidget);
    expect(find.text('Track bus'), findsOneWidget);
    expect(find.text('My alerts'), findsOneWidget);
  });

  testWidgets('does not allow a driver into the student dashboard', (
    WidgetTester tester,
  ) async {
    const driver = AuthenticatedUser(
      id: 'driver-profile-id',
      email: 'driver@muet.edu.pk',
      fullName: 'MUET Driver',
      role: UserRole.driver,
      profileComplete: true,
    );

    await tester.pumpWidget(
      const MaterialApp(home: StudentDashboardPage(user: driver)),
    );

    expect(find.byType(UnauthorizedPage), findsOneWidget);
    expect(find.text('Account configuration'), findsOneWidget);
  });
}

class _FakeStudentDashboardRepository implements StudentDashboardRepository {
  const _FakeStudentDashboardRepository(this.data);

  final StudentDashboardData? data;

  @override
  Future<StudentDashboardData?> load(String profileId) async => data;
}
