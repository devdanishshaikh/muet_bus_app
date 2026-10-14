import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/authenticated_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/pages/unauthorized_page.dart';
import '../domain/admin_dashboard_data.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
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
        data: (data) => _AdminDashboardContent(user: user, data: data),
      ),
    );
  }
}

class _AdminDashboardContent extends StatelessWidget {
  const _AdminDashboardContent({required this.user, required this.data});

  final AuthenticatedUser user;
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Welcome, ${user.fullName}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
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
