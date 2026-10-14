import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/authenticated_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/pages/unauthorized_page.dart';
import '../domain/student_dashboard_data.dart';
import '../domain/student_route.dart';
import 'student_alerts_page.dart';
import 'student_dashboard_providers.dart';
import 'student_live_tracking_page.dart';
import 'student_profile_page.dart';
import 'student_route_details_page.dart';
import 'student_routes_providers.dart';

/// The root scaffold for all student-facing screens.
///
/// Provides a [NavigationBar] with five destinations:
///   0 – Dashboard  (profile summary, active trip, quick actions)
///   1 – Bus Routes (active routes fetched from Supabase)
///   2 – Live Tracking (active student bus map)
///   3 – My Alerts  (placeholder; full alert management in a later step)
///   4 – Profile    (student identity, sign-out)
///
/// Access is guarded: only [UserRole.student] users reach this shell.
class StudentShellPage extends ConsumerStatefulWidget {
  const StudentShellPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  ConsumerState<StudentShellPage> createState() => _StudentShellPageState();
}

class _StudentShellPageState extends ConsumerState<StudentShellPage> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.alt_route_outlined),
      selectedIcon: Icon(Icons.alt_route),
      label: 'Bus Routes',
    ),
    NavigationDestination(
      icon: Icon(Icons.location_on_outlined),
      selectedIcon: Icon(Icons.location_on),
      label: 'Live Tracking',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_none_outlined),
      selectedIcon: Icon(Icons.notifications),
      label: 'My Alerts',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.user.role != UserRole.student) {
      return UnauthorizedPage(user: widget.user);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle(_selectedIndex)),
        actions: [
          if (_selectedIndex != 4)
            IconButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _DashboardTab(user: widget.user),
          _RoutesTab(user: widget.user),
          _LiveTrackingTab(user: widget.user),
          StudentAlertsPage(user: widget.user),
          StudentProfilePage(user: widget.user),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: _destinations,
      ),
    );
  }

  String _appBarTitle(int index) {
    return switch (index) {
      0 => 'Dashboard',
      1 => 'Bus Routes',
      2 => 'Live Tracking',
      3 => 'My Alerts',
      4 => 'Profile',
      _ => 'MUET Bus',
    };
  }
}

// ---------------------------------------------------------------------------
// Tab bodies — self-contained widgets that reuse existing pages/providers.
// ---------------------------------------------------------------------------

/// Dashboard tab: loads the student's profile & active trip from Supabase.
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab({required this.user});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(studentDashboardProvider(user.id));
    return dashboardState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _TabError(
        message: 'Could not load your dashboard.',
        onRetry: () => ref.invalidate(studentDashboardProvider(user.id)),
      ),
      data: (data) => _DashboardContent(user: user, data: data),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.user, required this.data});

  final AuthenticatedUser user;
  final StudentDashboardData? data;

  @override
  Widget build(BuildContext context) {
    final trip = data?.activeTrip;
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Welcome, ${user.fullName.isEmpty ? 'Student' : user.fullName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          _IdentityCard(user: user, studentId: data?.studentId),
          const SizedBox(height: 16),
          _ActiveTripCard(trip: trip),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user, required this.studentId});

  final AuthenticatedUser user;
  final String? studentId;

  @override
  Widget build(BuildContext context) {
    final trimmedName = user.fullName.trim();
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
                  Text(
                    user.fullName.isEmpty ? 'Student' : user.fullName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    studentId == null
                        ? 'Student profile details are not available yet.'
                        : 'Student ID: $studentId',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodySmall,
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

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({required this.trip});

  final ActiveTripSummary? trip;

  @override
  Widget build(BuildContext context) {
    if (trip == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.directions_bus_outlined),
          title: Text('No active trip'),
          subtitle: Text(
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

// ---------------------------------------------------------------------------

/// Routes tab: loads active routes from Supabase and navigates to details.
class _RoutesTab extends ConsumerWidget {
  const _RoutesTab({required this.user});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesState = ref.watch(activeStudentRoutesProvider);
    return routesState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _TabError(
        message: 'Could not load routes.',
        onRetry: () => ref.invalidate(activeStudentRoutesProvider),
      ),
      data: (routes) {
        if (routes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No active routes are available right now.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeStudentRoutesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: routes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _RouteCard(user: user, route: routes[index]),
          ),
        );
      },
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.user, required this.route});

  final AuthenticatedUser user;
  final StudentRoute route;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            Icons.alt_route,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(route.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            route.description?.isNotEmpty == true
                ? route.description!
                : '${route.stops.length} stop${route.stops.length == 1 ? '' : 's'}',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  StudentRouteDetailsPage(user: user, routeId: route.id),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Live Tracking tab: embeds the active student bus map in the shell body.
class _LiveTrackingTab extends StatelessWidget {
  const _LiveTrackingTab({required this.user});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context) {
    return StudentLiveTrackingPage(user: user, showAppBar: false);
  }
}

// ---------------------------------------------------------------------------

class _TabError extends StatelessWidget {
  const _TabError({required this.message, required this.onRetry});

  final String message;
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
            Text(message, textAlign: TextAlign.center),
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
