import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/authenticated_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/pages/unauthorized_page.dart';
import '../domain/admin_dashboard_data.dart';
import '../domain/admin_live_monitoring_data.dart';
import 'admin_dashboard_providers.dart';
import 'admin_live_monitoring_page.dart';
import 'admin_transport_management_pages.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.admin) {
      return UnauthorizedPage(user: user);
    }

    final dashboard = ref.watch(adminDashboardProvider);
    final activeTrips = ref.watch(activeAdminTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(adminDashboardProvider);
              ref.invalidate(activeAdminTripsProvider);
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AdminDashboardError(
          onRetry: () => ref.invalidate(adminDashboardProvider),
        ),
        data: (data) => _AdminDashboardContent(
          user: user,
          data: data,
          activeTrips: activeTrips,
        ),
      ),
    );
  }
}

class _AdminDashboardContent extends ConsumerWidget {
  const _AdminDashboardContent({
    required this.user,
    required this.data,
    required this.activeTrips,
  });

  final AuthenticatedUser user;
  final AdminDashboardData data;
  final AsyncValue<List<MonitoredBus>> activeTrips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminDashboardProvider);
        ref.invalidate(activeAdminTripsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _AdminProfileCard(user: user),
          const SizedBox(height: 24),
          Text(
            'Transport overview',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (data.isEmpty) ...[
            const SizedBox(height: 12),
            const _AdminDashboardEmpty(),
          ],
          const SizedBox(height: 12),
          _OverviewGrid(data: data),
          const SizedBox(height: 28),
          _ActiveTripsSection(activeTrips: activeTrips),
          const SizedBox(height: 28),
          _NavigationSection(
            title: 'Management',
            user: user,
            items: [
              _AdminNavigationItem('Bus Management', Icons.directions_bus),
              _AdminNavigationItem('Driver Management', Icons.badge_outlined),
              _AdminNavigationItem('Route Management', Icons.route_outlined),
            ],
          ),
          const SizedBox(height: 20),
          _NavigationSection(
            title: 'Assignments',
            user: user,
            items: [
              _AdminNavigationItem(
                'Bus Assignments',
                Icons.assignment_ind_outlined,
              ),
              _AdminNavigationItem(
                'Route Assignments',
                Icons.alt_route_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _NavigationSection(
            title: 'Monitoring',
            user: user,
            items: [
              _AdminNavigationItem(
                'Live Monitoring',
                Icons.location_searching_outlined,
              ),
              _AdminNavigationItem(
                'Route Schedules',
                Icons.schedule_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminProfileCard extends StatelessWidget {
  const _AdminProfileCard({required this.user});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                user.fullName.isNotEmpty
                    ? user.fullName[0].toUpperCase()
                    : 'A',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Chip(
                    label: Text('Admin'),
                    avatar: Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final items = [
      _OverviewItem('Total buses', data.totalBuses, Icons.directions_bus),
      _OverviewItem('Active buses', data.activeBuses, Icons.bus_alert_outlined),
      _OverviewItem('Total drivers', data.totalDrivers, Icons.badge_outlined),
      _OverviewItem(
        'Active driver assignments',
        data.activeDriverAssignments,
        Icons.assignment_ind_outlined,
      ),
      _OverviewItem('Total routes', data.totalRoutes, Icons.route_outlined),
      _OverviewItem('Active routes', data.activeRoutes, Icons.alt_route_outlined),
      _OverviewItem('Active trips', data.activeTrips, Icons.trip_origin_outlined),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (columnCount - 1)) /
            columnCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _OverviewTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _OverviewItem {
  const _OverviewItem(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({required this.item});

  final _OverviewItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(item.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label),
                  const SizedBox(height: 4),
                  Text(
                    '${item.value}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTripsSection extends ConsumerWidget {
  const _ActiveTripsSection({required this.activeTrips});

  final AsyncValue<List<MonitoredBus>> activeTrips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return activeTrips.when(
      loading: () => const _ActiveTripsLoading(),
      error: (error, _) => _ActiveTripsError(
        onRetry: () => ref.invalidate(activeAdminTripsProvider),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return const _ActiveTripsEmpty();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Trips',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${trips.length} active',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trips.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _ActiveTripCard(trip: trips[index]),
          ),
        ],
      );
    },
  );
}
}

class _ActiveTripsLoading extends StatelessWidget {
  const _ActiveTripsLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Trips',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => const _ActiveTripSkeleton(),
        ),
      ],
    );
  }
}

class _ActiveTripSkeleton extends StatelessWidget {
  const _ActiveTripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 120,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 80,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: 100,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 150,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 200,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTripsEmpty extends StatelessWidget {
  const _ActiveTripsEmpty();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.trip_origin_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No active trips',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active trips will appear here when they start.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTripsError extends StatelessWidget {
  const _ActiveTripsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Could not load active trips',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({required this.trip});

  final MonitoredBus trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = trip.location;
    final isStale = location == null || trip.isStale;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus_filled_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${trip.busNumber} • ${trip.busName}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _TripStatusChip(status: trip.tripStatus),
              ],
            ),
            const SizedBox(height: 8),
            Text('Route: ${trip.routeName}'),
            const SizedBox(height: 4),
            Text('Driver: ${trip.driverName}'),
            const SizedBox(height: 4),
            Text('Trip status: ${trip.tripStatus}'),
            const SizedBox(height: 4),
            Text(
              'Started: ${trip.tripStartedAt.toLocal().toString().split('.').first}',
            ),
            const SizedBox(height: 4),
            Text(
              location == null
                  ? 'Last location: No data yet'
                  : trip.isStale
                      ? 'Last location: ${_formatDateTime(location.recordedAt)} (stale)'
                      : 'Last location: ${_formatDateTime(location.recordedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isStale ? theme.colorScheme.error : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return local.toString().split('.').first;
  }
}

class _TripStatusChip extends StatelessWidget {
  const _TripStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status),
      backgroundColor: _statusColor(status),
      labelStyle: TextStyle(color: Colors.white),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _NavigationSection extends StatelessWidget {
  const _NavigationSection({
    required this.title,
    required this.user,
    required this.items,
  });

  final String title;
  final AuthenticatedUser user;
  final List<_AdminNavigationItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(item.icon),
            title: Text(item.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openAdminSection(context, user, item.title),
          ),
      ],
    );
  }
}

void _openAdminSection(
  BuildContext context,
  AuthenticatedUser user,
  String title,
) {
  final Widget page = switch (title) {
    'Bus Management' => AdminBusManagementPage(user: user),
    'Driver Management' => AdminDriverManagementPage(user: user),
    'Route Management' => AdminRouteManagementPage(user: user),
    'Bus Assignments' => AdminBusDriverAssignmentsPage(user: user),
    'Route Assignments' => AdminBusRouteAssignmentsPage(user: user),
    'Route Schedules' => AdminRouteSchedulesPage(user: user),
    'Live Monitoring' => AdminLiveMonitoringPage(user: user),
    _ => const SizedBox.shrink(),
  };
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

class _AdminNavigationItem {
  const _AdminNavigationItem(this.title, this.icon);

  final String title;
  final IconData icon;
}

class _AdminDashboardEmpty extends StatelessWidget {
  const _AdminDashboardEmpty();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.inbox_outlined),
      title: Text('No transport data is available yet.'),
    );
  }
}

class _AdminDashboardError extends StatelessWidget {
  const _AdminDashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'We could not load the transport overview.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}