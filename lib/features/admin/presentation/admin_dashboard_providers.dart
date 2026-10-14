import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_admin_dashboard_repository.dart';
import '../data/supabase_admin_transport_management_repository.dart';
import '../domain/admin_dashboard_data.dart';
import '../domain/admin_dashboard_repository.dart';
import '../domain/admin_transport_management_data.dart';
import '../domain/admin_transport_management_repository.dart';

final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>(
  (ref) => SupabaseAdminDashboardRepository(Supabase.instance.client),
);

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboardData>(
  (ref) => ref.watch(adminDashboardRepositoryProvider).load(),
);

final adminTransportManagementRepositoryProvider =
    Provider<AdminTransportManagementRepository>(
      (ref) => SupabaseAdminTransportManagementRepository(
        Supabase.instance.client,
      ),
    );

final adminBusesProvider = FutureProvider.autoDispose<List<AdminBus>>(
  (ref) => ref.watch(adminTransportManagementRepositoryProvider).loadBuses(),
);

final adminDriversProvider = FutureProvider.autoDispose<List<AdminDriver>>(
  (ref) => ref.watch(adminTransportManagementRepositoryProvider).loadDrivers(),
);

final adminRoutesProvider = FutureProvider.autoDispose<List<AdminRoute>>(
  (ref) => ref.watch(adminTransportManagementRepositoryProvider).loadRoutes(),
);

final adminStopsProvider = FutureProvider.autoDispose
    .family<List<AdminStop>, String>(
      (ref, routeId) =>
          ref.watch(adminTransportManagementRepositoryProvider).loadStops(routeId),
    );

final adminBusDriverAssignmentsProvider =
    FutureProvider.autoDispose<List<AdminBusDriverAssignment>>(
      (ref) => ref
          .watch(adminTransportManagementRepositoryProvider)
          .loadBusDriverAssignments(),
    );

final adminBusRouteAssignmentsProvider =
    FutureProvider.autoDispose<List<AdminBusRouteAssignment>>(
      (ref) => ref
          .watch(adminTransportManagementRepositoryProvider)
          .loadBusRouteAssignments(),
    );

final adminRouteSchedulesProvider =
    FutureProvider.autoDispose<List<AdminRouteSchedule>>(
      (ref) => ref
          .watch(adminTransportManagementRepositoryProvider)
          .loadRouteSchedules(),
    );
