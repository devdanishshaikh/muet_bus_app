import 'student_dashboard_data.dart';

abstract interface class StudentDashboardRepository {
  Future<StudentDashboardData?> load(String profileId);
}
