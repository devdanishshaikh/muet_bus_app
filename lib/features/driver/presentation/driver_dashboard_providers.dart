import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_driver_dashboard_repository.dart';
import '../domain/driver_dashboard_data.dart';
import '../domain/driver_dashboard_repository.dart';

final driverDashboardRepositoryProvider = Provider<DriverDashboardRepository>(
  (ref) => SupabaseDriverDashboardRepository(Supabase.instance.client),
);

final driverDashboardProvider = FutureProvider.autoDispose
    .family<DriverDashboardData?, String>((ref, profileId) {
      return ref.watch(driverDashboardRepositoryProvider).load(profileId);
    });

final driverDashboardActionLoadingProvider = StateProvider.autoDispose
    .family<bool, String>((ref, profileId) => false);
