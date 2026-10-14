import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/config/environment.dart';
import '../../auth/domain/authenticated_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/pages/unauthorized_page.dart';
import '../domain/student_live_tracking.dart';
import '../domain/student_tracking_selection.dart';
import 'student_live_tracking_providers.dart';

class StudentLiveTrackingPage extends ConsumerWidget {
  const StudentLiveTrackingPage({
    required this.user,
    this.routeId,
    this.busId,
    this.showAppBar = true,
    super.key,
  });

  final AuthenticatedUser user;
  final String? routeId;
  final String? busId;
  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.student) {
      return UnauthorizedPage(user: user);
    }

    final selection = routeId == null && busId == null
        ? null
        : StudentTrackingSelection(routeId: routeId, busId: busId);

    Future<void> refresh() async {
      if (selection == null) {
        ref.invalidate(activeStudentLiveTrackingProvider);
        try {
          await ref.read(activeStudentLiveTrackingProvider.future);
        } catch (_) {}
        return;
      }

      ref.invalidate(studentLiveTrackingProvider(selection));
      try {
        await ref.read(studentLiveTrackingProvider(selection).future);
      } catch (_) {}
    }

    void refreshNow() {
      if (selection == null) {
        ref.invalidate(activeStudentLiveTrackingProvider);
      } else {
        ref.invalidate(studentLiveTrackingProvider(selection));
      }
    }

    if (!Environment.isGoogleMapsConfigured) {
      return _TrackingChrome(
        title: selection == null ? 'Live Tracking' : 'Track bus',
        showAppBar: showAppBar,
        onRefresh: refreshNow,
        child: const _TrackingConfigurationError(),
      );
    }

    if (selection == null) {
      final trackingState = ref.watch(activeStudentLiveTrackingProvider);
      return _TrackingChrome(
        title: 'Live Tracking',
        showAppBar: showAppBar,
        onRefresh: refreshNow,
        child: trackingState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _TrackingError(onRetry: refreshNow),
          data: (buses) => _TrackingContent(
            buses: buses,
            embedded: !showAppBar,
            onRefresh: refresh,
          ),
        ),
      );
    }

    final trackingState = ref.watch(studentLiveTrackingProvider(selection));
    return _TrackingChrome(
      title: 'Track bus',
      showAppBar: showAppBar,
      onRefresh: refreshNow,
      child: trackingState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _TrackingError(onRetry: refreshNow),
        data: (tracking) => _TrackingContent(
          buses: tracking == null ? const [] : [tracking],
          embedded: !showAppBar,
          onRefresh: refresh,
        ),
      ),
    );
  }
}

class _TrackingChrome extends StatelessWidget {
  const _TrackingChrome({
    required this.title,
    required this.showAppBar,
    required this.onRefresh,
    required this.child,
  });

  final String title;
  final bool showAppBar;
  final VoidCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!showAppBar) {
      return child;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: child,
    );
  }
}

class _TrackingContent extends StatelessWidget {
  const _TrackingContent({
    required this.buses,
    required this.embedded,
    required this.onRefresh,
  });

  final List<StudentLiveTracking> buses;
  final bool embedded;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (buses.isEmpty) {
      return _TrackingEmpty(onRefresh: onRefresh);
    }

    return Column(
      children: [
        if (embedded) _TrackingSummaryBar(buses: buses, onRefresh: onRefresh),
        Expanded(
          child: _TrackingBody(buses: buses, onRefresh: onRefresh),
        ),
      ],
    );
  }
}

class _TrackingSummaryBar extends StatelessWidget {
  const _TrackingSummaryBar({required this.buses, required this.onRefresh});

  final List<StudentLiveTracking> buses;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = buses.length;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.directions_bus_filled_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count active bus${count == 1 ? '' : 'es'}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            IconButton(
              onPressed: () => onRefresh(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({required this.buses, required this.onRefresh});

  final List<StudentLiveTracking> buses;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final busesWithLocation = buses
        .where((bus) => bus.hasValidLocation)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Row(
            children: [
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _MapPane(buses: busesWithLocation),
                ),
              ),
              Expanded(
                flex: 4,
                child: _BusList(buses: buses, onRefresh: onRefresh),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: buses.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return SizedBox(
                  height: 360,
                  child: _MapPane(buses: busesWithLocation),
                );
              }
              return _BusCard(bus: buses[index - 1]);
            },
          ),
        );
      },
    );
  }
}

class _MapPane extends StatelessWidget {
  const _MapPane({required this.buses});

  final List<StudentLiveTracking> buses;

  @override
  Widget build(BuildContext context) {
    if (buses.isEmpty) {
      return const _MapUnavailableCard(
        message: 'No active buses have a latest location yet.',
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _TrackingMap(buses: buses),
    );
  }
}

class _TrackingMap extends StatelessWidget {
  const _TrackingMap({required this.buses});

  final List<StudentLiveTracking> buses;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    for (final bus in buses) {
      final location = bus.location;
      if (location == null) {
        continue;
      }
      markers.add(
        Marker(
          markerId: MarkerId('student-bus-${bus.tripId}'),
          position: LatLng(location.latitude, location.longitude),
          infoWindow: InfoWindow(title: bus.busNumber, snippet: bus.routeName),
          onTap: () => _showBusDetails(context, bus),
        ),
      );
    }

    final cameraTarget = _centerOf(buses);
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: cameraTarget,
        zoom: buses.length == 1 ? 15 : 12,
      ),
      markers: markers,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
    );
  }

  LatLng _centerOf(List<StudentLiveTracking> buses) {
    var latitude = 0.0;
    var longitude = 0.0;
    var count = 0;
    for (final bus in buses) {
      final location = bus.location;
      if (location == null) {
        continue;
      }
      latitude += location.latitude;
      longitude += location.longitude;
      count++;
    }
    return LatLng(latitude / count, longitude / count);
  }

  void _showBusDetails(BuildContext context, StudentLiveTracking bus) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final location = bus.location;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.busNumber,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Bus Number', value: bus.busNumber),
                    _DetailRow(label: 'Bus Name', value: bus.busName),
                    _DetailRow(label: 'Route', value: bus.routeName),
                    _DetailRow(
                      label: 'Last location update',
                      value: location == null
                          ? 'No location received'
                          : _formatDateTime(location.recordedAt),
                    ),
                    _DetailRow(
                      label: 'Status',
                      value: _formatStatus(bus.tripStatus),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BusList extends StatelessWidget {
  const _BusList({required this.buses, required this.onRefresh});

  final List<StudentLiveTracking> buses;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: buses.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _BusCard(bus: buses[index]),
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  const _BusCard({required this.bus});

  final StudentLiveTracking bus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = bus.location;
    final hasLocation = location != null;
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
                    '${bus.busNumber} - ${bus.busName}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(_formatStatus(bus.tripStatus))),
              ],
            ),
            const SizedBox(height: 8),
            Text('Route: ${bus.routeName}'),
            const SizedBox(height: 4),
            Text('Bus status: ${bus.busStatus}'),
            const SizedBox(height: 4),
            Text(
              hasLocation
                  ? 'Last location: ${_formatDateTime(location!.recordedAt)}'
                  : 'Last location: No data yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasLocation ? null : theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _TrackingEmpty extends StatelessWidget {
  const _TrackingEmpty({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_outlined, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'No buses are currently running.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => onRefresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapUnavailableCard extends StatelessWidget {
  const _MapUnavailableCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingConfigurationError extends StatelessWidget {
  const _TrackingConfigurationError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48),
            SizedBox(height: 12),
            Text(
              'Live tracking is not configured for this build.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.onRetry});

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
              'We could not load live bus tracking.',
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

String _formatDateTime(DateTime value) {
  return value.toLocal().toString().split('.').first;
}

String _formatStatus(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Unknown';
  }
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
}
