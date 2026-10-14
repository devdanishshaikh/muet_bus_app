import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/config/environment.dart';
import '../../auth/domain/authenticated_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/pages/unauthorized_page.dart';
import '../domain/admin_live_monitoring_data.dart';
import 'admin_live_monitoring_providers.dart';

class AdminLiveMonitoringPage extends ConsumerWidget {
  const AdminLiveMonitoringPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.admin) {
      return UnauthorizedPage(user: user);
    }

    final monitoringState = ref.watch(adminLiveMonitoringProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Monitoring'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(adminLiveMonitoringProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: monitoringState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MonitoringError(
          onRetry: () => ref.invalidate(adminLiveMonitoringProvider),
        ),
        data: (snapshot) => _MonitoringContent(snapshot: snapshot),
      ),
    );
  }
}

class _MonitoringContent extends StatelessWidget {
  const _MonitoringContent({required this.snapshot});

  final AdminLiveMonitoringSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.isEmpty) {
      return const _MonitoringEmpty();
    }

    return Column(
      children: [
        _MonitoringStatusBar(snapshot: snapshot),
        Expanded(
          child: _MonitoringBody(snapshot: snapshot),
        ),
      ],
    );
  }
}

class _MonitoringBody extends StatelessWidget {
  const _MonitoringBody({required this.snapshot});

  final AdminLiveMonitoringSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final busesWithLocation =
        snapshot.buses.where((b) => b.hasValidLocation && !b.isStale).toList();

    if (!Environment.isGoogleMapsConfigured) {
      return _BusList(buses: snapshot.buses);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Row(
            children: [
              Expanded(
                flex: 6,
                child: busesWithLocation.isNotEmpty
                    ? _MonitoringMap(buses: busesWithLocation)
                    : const Padding(
                        padding: EdgeInsets.all(16),
                        child: _OfflineLocationBanner(
                          message:
                              'No buses with a recent location to show on the map.',
                        ),
                      ),
              ),
              Expanded(
                flex: 4,
                child: _BusList(buses: snapshot.buses),
              ),
            ],
          );
        }

        return Column(
          children: [
            if (busesWithLocation.isNotEmpty)
              SizedBox(
                height: 320,
                child: _MonitoringMap(buses: busesWithLocation),
              ),
            if (busesWithLocation.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: _OfflineLocationBanner(
                  message:
                      'No buses with a recent location to show on the map.',
                ),
              ),
            Expanded(child: _BusList(buses: snapshot.buses)),
          ],
        );
      },
    );
  }
}

class _MonitoringMap extends StatelessWidget {
  const _MonitoringMap({required this.buses});

  final List<MonitoredBus> buses;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    for (final bus in buses) {
      final loc = bus.location;
      if (loc == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId('bus-${bus.tripId}'),
          position: LatLng(loc.latitude, loc.longitude),
          infoWindow: InfoWindow(
            title: bus.busNumber,
            snippet: '${bus.routeName} • ${bus.driverName}',
          ),
        ),
      );
    }

    // Centre on the first bus.
    final first = buses.first.location!;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(first.latitude, first.longitude),
          zoom: 13,
        ),
        markers: markers,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
      ),
    );
  }
}

class _MonitoringStatusBar extends StatelessWidget {
  const _MonitoringStatusBar({required this.snapshot});

  final AdminLiveMonitoringSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = snapshot.realtimeStatus;
    final isLive = status == AdminMonitoringStatus.connected;
    final isReconnecting = status == AdminMonitoringStatus.reconnecting;
    final isDisconnected = status == AdminMonitoringStatus.disconnected ||
        status == AdminMonitoringStatus.error;
    final error = snapshot.realtimeError;

    final label = isLive
        ? 'Live • ${snapshot.buses.length} active trip${snapshot.buses.length == 1 ? '' : 's'}'
        : isReconnecting
            ? 'Reconnecting…'
            : isDisconnected
                ? 'Disconnected'
                : 'Connecting…';

    final icon = isLive
        ? Icons.wifi
        : isReconnecting
            ? Icons.sync
            : isDisconnected
                ? Icons.cloud_off_outlined
                : Icons.sync;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isLive
          ? theme.colorScheme.primaryContainer
          : isReconnecting
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error != null && !isLive ? '$label — $error' : label,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _BusList extends StatelessWidget {
  const _BusList({required this.buses});

  final List<MonitoredBus> buses;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: buses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _BusCard(bus: buses[index]),
    );
  }
}

class _BusCard extends StatelessWidget {
  const _BusCard({required this.bus});

  final MonitoredBus bus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = bus.location;
    final isOffline = location == null || bus.isStale;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus_filled_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${bus.busNumber} • ${bus.busName}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _BusStatusChip(isOffline: isOffline),
              ],
            ),
            const SizedBox(height: 8),
            Text('Route: ${bus.routeName}'),
            const SizedBox(height: 4),
            Text('Driver: ${bus.driverName}'),
            const SizedBox(height: 4),
            Text('Trip status: ${bus.tripStatus}'),
            const SizedBox(height: 4),
            Text(
              location == null
                  ? 'Last location: No data yet'
                  : bus.isStale
                      ? 'Last location: ${_formatDateTime(location.recordedAt)} (stale)'
                      : 'Last location: ${_formatDateTime(location.recordedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isOffline ? theme.colorScheme.error : null,
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

class _BusStatusChip extends StatelessWidget {
  const _BusStatusChip({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        isOffline ? Icons.location_off_outlined : Icons.location_on_outlined,
        size: 16,
      ),
      label: Text(isOffline ? 'Offline' : 'Tracking'),
    );
  }
}

class _MonitoringEmpty extends StatelessWidget {
  const _MonitoringEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 48),
            SizedBox(height: 12),
            Text(
              'No active trips at the moment.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Active bus trips will appear here in real time.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineLocationBanner extends StatelessWidget {
  const _OfflineLocationBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_off_outlined),
        title: const Text('Map unavailable'),
        subtitle: Text(message),
      ),
    );
  }
}

class _MonitoringError extends StatelessWidget {
  const _MonitoringError({required this.onRetry});

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
              'We could not load live monitoring data.',
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
