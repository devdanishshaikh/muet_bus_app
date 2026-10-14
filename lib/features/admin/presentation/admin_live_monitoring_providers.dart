import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_admin_live_monitoring_repository.dart';
import '../domain/admin_live_monitoring_data.dart';
import '../domain/admin_live_monitoring_repository.dart';

final adminLiveMonitoringRepositoryProvider =
    Provider<AdminLiveMonitoringRepository>(
  (ref) => SupabaseAdminLiveMonitoringRepository(Supabase.instance.client),
);

final adminLiveMonitoringProvider =
    StreamProvider.autoDispose<AdminLiveMonitoringSnapshot>((ref) {
  return ref.watch(adminLiveMonitoringRepositoryProvider).watchActiveTrips();
});
