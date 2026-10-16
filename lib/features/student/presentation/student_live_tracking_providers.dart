import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/environment.dart';
import '../data/supabase_student_live_tracking_repository.dart';
import '../domain/student_live_tracking.dart';
import '../domain/student_live_tracking_repository.dart';
import '../domain/student_tracking_selection.dart';

final studentLiveTrackingRepositoryProvider =
    Provider<StudentLiveTrackingRepository>(
  (ref) => SupabaseStudentLiveTrackingRepository(Supabase.instance.client),
);

final activeStudentLiveTrackingProvider =
    FutureProvider.autoDispose<List<StudentLiveTracking>>((ref) {
  if (!Environment.isConfigured) {
    return const [];
  }
  return ref.watch(studentLiveTrackingRepositoryProvider).loadActiveBuses();
});

final studentLiveTrackingProvider = FutureProvider.autoDispose
    .family<StudentLiveTracking?, StudentTrackingSelection>((ref, selection) {
  if (!Environment.isConfigured) {
    return null;
  }
  return ref
      .watch(studentLiveTrackingRepositoryProvider)
      .load(routeId: selection.routeId, busId: selection.busId);
});

/// Stream provider for realtime active bus tracking.
///
/// This provider subscribes to Supabase Realtime updates for bus_locations
/// and yields updated lists of active buses with their latest locations.
final activeStudentLiveTrackingStreamProvider =
    StreamProvider.autoDispose<List<StudentLiveTracking>>((ref) async* {
  if (!Environment.isConfigured) {
    yield const [];
    return;
  }

  // Initial load
  final repo = ref.watch(studentLiveTrackingRepositoryProvider);
  final initial = await repo.loadActiveBuses();
  yield initial;

  // Subscribe to realtime updates
  await for (final update in repo.watchActiveBuses()) {
    yield update;
  }
});