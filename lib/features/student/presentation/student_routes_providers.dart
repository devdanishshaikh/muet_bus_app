import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_student_routes_repository.dart';
import '../domain/student_route.dart';
import '../domain/student_routes_repository.dart';

final studentRoutesRepositoryProvider = Provider<StudentRoutesRepository>(
  (ref) => SupabaseStudentRoutesRepository(Supabase.instance.client),
);

final activeStudentRoutesProvider =
    FutureProvider.autoDispose<List<StudentRoute>>((ref) {
  return ref.watch(studentRoutesRepositoryProvider).loadRoutes();
});

final activeStudentRoutesWithBusesProvider =
    FutureProvider.autoDispose<List<StudentRouteDetails>>((ref) {
  return ref.watch(studentRoutesRepositoryProvider).loadRoutesWithActiveBuses();
});

final studentRouteDetailsProvider = FutureProvider.autoDispose
    .family<StudentRouteDetails?, String>((ref, routeId) {
  return ref
      .watch(studentRoutesRepositoryProvider)
      .loadRouteDetails(routeId);
});