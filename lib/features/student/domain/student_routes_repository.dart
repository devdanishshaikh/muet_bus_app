import 'student_route.dart';

abstract interface class StudentRoutesRepository {
  Future<List<StudentRoute>> loadRoutes();

  Future<StudentRouteDetails?> loadRouteDetails(String routeId);

  Future<List<StudentRouteDetails>> loadRoutesWithActiveBuses();
}
