import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_student_dashboard_repository.dart';
import '../domain/student_dashboard_data.dart';
import '../domain/student_dashboard_repository.dart';

final studentDashboardRepositoryProvider = Provider<StudentDashboardRepository>(
  (ref) {
    return SupabaseStudentDashboardRepository(Supabase.instance.client);
  },
);

final studentDashboardProvider = FutureProvider.autoDispose
    .family<StudentDashboardData?, String>((ref, profileId) {
      return ref.watch(studentDashboardRepositoryProvider).load(profileId);
    });
