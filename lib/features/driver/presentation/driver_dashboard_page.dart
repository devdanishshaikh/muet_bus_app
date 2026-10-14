import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/authenticated_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/pages/unauthorized_page.dart';
import '../domain/driver_dashboard_data.dart';
import '../domain/driver_location_state.dart';
import 'driver_dashboard_providers.dart';
import 'driver_location_providers.dart';

class DriverDashboardPage extends ConsumerStatefulWidget {
  const DriverDashboardPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  ConsumerState<DriverDashboardPage> createState() =>
      _DriverDashboardPageState();
}

class _DriverDashboardPageState extends ConsumerState<DriverDashboardPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(driverLocationControllerProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      controller.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.role != UserRole.driver) {
      return UnauthorizedPage(user: widget.user);
    }

    final dashboard = ref.watch(driverDashboardProvider(widget.user.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(driverLocationControllerProvider.notifier).stop();
              await ref.read(authControllerProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DriverError(
          onRetry: () =>
              ref.invalidate(driverDashboardProvider(widget.user.id)),
        ),
        data: (data) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            final controller = ref.read(
              driverLocationControllerProvider.notifier,
            );
            if (data?.activeTrip == null) {
              controller.stop();
            } else {
              controller.start(data!.activeTrip!.id);
            }
          });
          return data == null
              ? const _DriverProfileEmpty()
              : _DriverDashboardContent(user: widget.user, data: data);
        },
      ),
    );
  }
}

class _DriverDashboardContent extends ConsumerWidget {
  const _DriverDashboardContent({required this.user, required this.data});

  final AuthenticatedUser user;
  final DriverDashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(driverDashboardActionLoadingProvider(user.id));
    final locationState = ref.watch(driverLocationControllerProvider);
    final assignment = data.assignment;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Welcome, ${data.driverName}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        _AssignmentCard(assignment: assignment),
        const SizedBox(height: 16),
        _TripCard(trip: data.activeTrip),
        if (data.activeTrip != null) ...[
          const SizedBox(height: 16),
          _LocationStatusCard(state: locationState),
        ],
        const SizedBox(height: 24),
        if (data.activeTrip != null)
          FilledButton.icon(
            onPressed: isLoading
                ? null
                : () => _endTrip(context, ref, data.activeTrip!.id),
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.stop_circle_outlined),
            label: const Text('End trip'),
          )
        else
          FilledButton.icon(
            onPressed: data.canStartTrip && !isLoading
                ? () => _startTrip(context, ref, assignment!)
                : null,
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle_outline),
            label: const Text('Start trip'),
          ),
      ],
    );
  }

  Future<void> _startTrip(
    BuildContext context,
    WidgetRef ref,
    DriverAssignment assignment,
  ) async {
    ref.read(driverDashboardActionLoadingProvider(user.id).notifier).state =
        true;
    try {
      final trip = await ref
          .read(driverDashboardRepositoryProvider)
          .startTrip(profileId: user.id, assignment: assignment);
      await ref.read(driverLocationControllerProvider.notifier).start(trip.id);
      if (!context.mounted) {
        return;
      }
      ref.invalidate(driverDashboardProvider(user.id));
      _showMessage(context, 'Trip started.');
    } catch (_) {
      if (context.mounted) {
        _showMessage(
          context,
          'Trip could not be started. Check your assignment.',
        );
      }
    } finally {
      ref.read(driverDashboardActionLoadingProvider(user.id).notifier).state =
          false;
    }
  }

  Future<void> _endTrip(
    BuildContext context,
    WidgetRef ref,
    String tripId,
  ) async {
    ref.read(driverDashboardActionLoadingProvider(user.id).notifier).state =
        true;
    try {
      await ref
          .read(driverDashboardRepositoryProvider)
          .endTrip(profileId: user.id, tripId: tripId);
      await ref.read(driverLocationControllerProvider.notifier).stop();
      if (!context.mounted) {
        return;
      }
      ref.invalidate(driverDashboardProvider(user.id));
      _showMessage(context, 'Trip completed.');
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Trip could not be ended.');
      }
    } finally {
      ref.read(driverDashboardActionLoadingProvider(user.id).notifier).state =
          false;
    }
  }

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment});

  final DriverAssignment? assignment;

  @override
  Widget build(BuildContext context) {
    if (assignment == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.assignment_late_outlined),
          title: Text('No active assignment'),
          subtitle: Text(
            'A bus and route assignment from an administrator is required.',
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
            Text(
              'Current assignment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              '${assignment!.busNumber} • ${assignment!.busName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('Bus status: ${assignment!.busStatus}'),
            const SizedBox(height: 6),
            Text('Route: ${assignment!.routeName}'),
            if (assignment!.routeDescription?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(assignment!.routeDescription!),
            ],
            const SizedBox(height: 6),
            Text('Route status: ${assignment!.routeStatus}'),
            const SizedBox(height: 6),
            Text(
              assignment!.isActive
                  ? 'Assignment status: active'
                  : 'Assignment status: inactive',
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final DriverTrip? trip;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          trip == null
              ? Icons.pause_circle_outline
              : Icons.directions_bus_filled_outlined,
        ),
        title: Text(
          trip == null ? 'No active trip' : 'Trip status: ${trip!.status}',
        ),
        subtitle: Text(
          trip == null
              ? 'Start a trip only after an active assignment is available.'
              : 'Started: ${trip!.startedAt.toLocal().toString().split('.').first}',
        ),
      ),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({required this.state});

  final DriverLocationState state;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (state.status) {
      DriverLocationStatus.requestingPermission =>
        'Requesting location permission',
      DriverLocationStatus.permissionDenied => 'Location permission denied',
      DriverLocationStatus.serviceDisabled => 'Location services are disabled',
      DriverLocationStatus.tracking => 'Publishing live location',
      DriverLocationStatus.paused => 'Location publishing paused',
      DriverLocationStatus.unavailable => 'Location is unavailable',
      DriverLocationStatus.error => 'Location publishing error',
      DriverLocationStatus.stopped => 'Location publishing stopped',
      DriverLocationStatus.idle => 'Location publishing is idle',
    };
    return Card(
      child: ListTile(
        leading: Icon(
          state.status == DriverLocationStatus.tracking
              ? Icons.gps_fixed
              : Icons.gps_off,
        ),
        title: Text(statusText),
        subtitle: Text(
          state.message ??
              (state.lastRecordedAt == null
                  ? 'No location published yet.'
                  : 'Last published: ${state.lastRecordedAt!.toLocal().toString().split('.').first}'),
        ),
      ),
    );
  }
}

class _DriverProfileEmpty extends StatelessWidget {
  const _DriverProfileEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Your driver profile is not configured yet. Contact an administrator.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _DriverError extends StatelessWidget {
  const _DriverError({required this.onRetry});

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
              'We could not load your driver dashboard.',
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
