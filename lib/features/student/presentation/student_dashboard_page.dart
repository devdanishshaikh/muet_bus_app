import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/authenticated_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/pages/unauthorized_page.dart';
import '../domain/student_dashboard_data.dart';
import 'student_dashboard_providers.dart';
import 'student_live_tracking_page.dart';
import 'student_routes_page.dart';

class StudentDashboardPage extends ConsumerWidget {
  const StudentDashboardPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.student) {
      return UnauthorizedPage(user: user);
    }

    final dashboardState = ref.watch(studentDashboardProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: dashboardState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DashboardError(
          onRetry: () => ref.invalidate(studentDashboardProvider(user.id)),
        ),
        data: (data) => _DashboardContent(
          user: user,
          data: data,
          onRefresh: () async {
            ref.invalidate(studentDashboardProvider(user.id));
          },
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.user,
    required this.data,
    required this.onRefresh,
  });

  final AuthenticatedUser user;
  final StudentDashboardData? data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Welcome, ${user.fullName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          _StudentIdentityCard(name: user.fullName, studentId: data?.studentId),
          const SizedBox(height: 16),
          _CurrentTripCard(trip: data?.activeTrip),
          const SizedBox(height: 24),
          Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _QuickActions(user: user, trip: data?.activeTrip),
        ],
      ),
    );
  }
}

class _StudentIdentityCard extends StatelessWidget {
  const _StudentIdentityCard({required this.name, required this.studentId});

  final String name;
  final String? studentId;

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    studentId == null
                        ? 'Student profile details are not available yet.'
                        : 'Student ID: $studentId',
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

class _CurrentTripCard extends StatelessWidget {
  const _CurrentTripCard({required this.trip});

  final ActiveTripSummary? trip;

  @override
  Widget build(BuildContext context) {
    if (trip == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.directions_bus_outlined),
          title: const Text('No active trip'),
          subtitle: const Text(
            'Current bus and route information will appear here when available.',
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus_filled_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Current trip',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(trip!.tripStatus)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${trip!.busNumber} • ${trip!.busName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('Route: ${trip!.routeName}'),
            if (trip!.routeDescription?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(trip!.routeDescription!),
            ],
            const SizedBox(height: 6),
            Text('Bus status: ${trip!.busStatus}'),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.user, required this.trip});

  final AuthenticatedUser user;
  final ActiveTripSummary? trip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DashboardAction(
          icon: Icons.alt_route,
          label: 'View routes',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StudentRoutesPage(user: user),
              ),
            );
          },
        ),
        _DashboardAction(
          icon: Icons.location_on_outlined,
          label: 'Track bus',
          onPressed: trip?.routeId == null && trip?.busId == null
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StudentLiveTrackingPage(
                        user: user,
                        routeId: trip?.routeId,
                        busId: trip?.busId,
                      ),
                    ),
                  );
                },
        ),
        const _DashboardAction(
          icon: Icons.notifications_none,
          label: 'My alerts',
        ),
      ],
    );
  }
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

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
              'We could not load your student dashboard.',
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
