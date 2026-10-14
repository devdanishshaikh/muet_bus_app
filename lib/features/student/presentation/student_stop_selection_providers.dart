import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/environment.dart';
import '../data/supabase_student_stop_selection_repository.dart';
import '../domain/student_stop_selection.dart';
import '../domain/student_stop_selection_repository.dart';

final studentStopSelectionRepositoryProvider =
    Provider<StudentStopSelectionRepository>(
      (ref) => SupabaseStudentStopSelectionRepository(Supabase.instance.client),
    );

final studentStopSelectionsProvider = FutureProvider.autoDispose
    .family<List<StudentStopSelection>, String>((ref, profileId) {
      if (!Environment.isConfigured) {
        return Future.value(const []);
      }
      return ref
          .watch(studentStopSelectionRepositoryProvider)
          .loadForStudent(profileId);
    });

final selectedStudentStopProvider = StateProvider.autoDispose
    .family<String?, String>((ref, routeId) => null);

final studentStopSelectionSavingProvider = StateProvider.autoDispose
    .family<bool, String>((ref, routeId) => false);

final selectedStudentAlertRadiusProvider = StateProvider.autoDispose
    .family<double?, String>((ref, routeId) => null);
