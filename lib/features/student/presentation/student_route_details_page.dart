import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/authenticated_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/pages/unauthorized_page.dart';
import '../domain/student_eta.dart';
import '../domain/student_live_tracking.dart';
import '../domain/student_route.dart';
import '../domain/student_stop_selection.dart';
import '../domain/student_tracking_selection.dart';
import 'student_live_tracking_page.dart';
import 'student_live_tracking_providers.dart';
import 'student_notification_providers.dart';
import 'student_stop_selection_providers.dart';
import 'student_routes_providers.dart';

class StudentRouteDetailsPage extends ConsumerWidget {
  const StudentRouteDetailsPage({
    required this.user,
    required this.routeId,
    super.key,
  });

  final AuthenticatedUser user;
  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.student) {
      return UnauthorizedPage(user: user);
    }

    final detailsState = ref.watch(studentRouteDetailsProvider(routeId));
    return Scaffold(
      appBar: AppBar(title: const Text('Route details')),
      body: detailsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DetailsError(
          onRetry: () => ref.invalidate(studentRouteDetailsProvider(routeId)),
        ),
        data: (details) {
          if (details == null) {
            return const Center(
              child: Text('This route is no longer available.'),
            );
          }
          return _RouteDetailsContent(user: user, details: details);
        },
      ),
    );
  }
}

class _RouteDetailsContent extends ConsumerWidget {
  const _RouteDetailsContent({required this.user, required this.details});

  final AuthenticatedUser user;
  final StudentRouteDetails details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = details.route;
    final savedSelections = ref.watch(studentStopSelectionsProvider(user.id));
    final selectedStopId = ref.watch(selectedStudentStopProvider(route.id));
    final trackingSelection = StudentTrackingSelection(
      routeId: route.id,
      busId: details.activeBus?.busId,
    );
    final tracking = ref.watch(studentLiveTrackingProvider(trackingSelection));
    final savedSelection = _findSavedSelection(
      savedSelections.asData?.value,
      route.stops,
    );
    final effectiveStopId = selectedStopId ?? savedSelection?.stopId;
    final selectedStop = _findStop(route.stops, effectiveStopId);
    if (savedSelection != null &&
        savedSelection.enabled &&
        savedSelection.busId == details.activeBus?.busId &&
        selectedStop != null) {
      ref.listen<AsyncValue<StudentLiveTracking?>>(
        studentLiveTrackingProvider(trackingSelection),
        (_, next) {
          final liveTracking = next.asData?.value;
          if (liveTracking != null) {
            unawaited(
              ref
                  .read(studentArrivalNotificationMonitorProvider)
                  .handleTrackingUpdate(
                    profileId: user.id,
                    selection: savedSelection,
                    stop: selectedStop,
                    tracking: liveTracking,
                  ),
            );
          }
        },
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(route.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (route.description?.isNotEmpty == true) ...[
          Text(route.description!),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            const Text('Status: '),
            Chip(label: Text(route.status)),
          ],
        ),
        const SizedBox(height: 24),
        Text('Stops', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (route.stops.isEmpty)
          const Card(
            child: ListTile(
              title: Text('No stops available'),
              subtitle: Text('Stop information has not been configured yet.'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < route.stops.length; index++)
                  _StopTile(
                    stop: route.stops[index],
                    isLast: index == route.stops.length - 1,
                    selected: route.stops[index].id == effectiveStopId,
                    onSelected: (stopId) =>
                        ref
                                .read(
                                  selectedStudentStopProvider(
                                    route.id,
                                  ).notifier,
                                )
                                .state =
                            stopId,
                  ),
              ],
            ),
          ),
        if (route.stops.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StopSelectionActions(
            profileId: user.id,
            routeId: route.id,
            activeBus: details.activeBus,
            selectedStop: selectedStop,
            savedSelection: savedSelection,
            isLoading: savedSelections.isLoading,
            onSaved: () =>
                ref.invalidate(studentStopSelectionsProvider(user.id)),
          ),
        ],
        const SizedBox(height: 24),
        _EtaCard(tracking: tracking, selectedStop: selectedStop),
        const SizedBox(height: 24),
        Text('Current bus', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _BusInformation(user: user, routeId: route.id, bus: details.activeBus),
      ],
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.stop,
    required this.isLast,
    required this.selected,
    required this.onSelected,
  });

  final StudentRouteStop stop;
  final bool isLast;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ChoiceChip(
        label: Text('${stop.stopOrder}'),
        selected: selected,
        onSelected: (_) => onSelected(stop.id),
      ),
      onTap: () => onSelected(stop.id),
      title: Text(stop.name),
      subtitle: Text('Stop ${stop.stopOrder}'),
      shape: isLast
          ? null
          : const Border(bottom: BorderSide(color: Colors.black12)),
    );
  }
}

StudentStopSelection? _findSavedSelection(
  List<StudentStopSelection>? selections,
  List<StudentRouteStop> stops,
) {
  if (selections == null) {
    return null;
  }
  for (final selection in selections) {
    if (stops.any((stop) => stop.id == selection.stopId)) {
      return selection;
    }
  }
  return null;
}

StudentRouteStop? _findStop(List<StudentRouteStop> stops, String? stopId) {
  if (stopId == null) {
    return null;
  }
  for (final stop in stops) {
    if (stop.id == stopId) {
      return stop;
    }
  }
  return null;
}

class _StopSelectionActions extends ConsumerWidget {
  const _StopSelectionActions({
    required this.profileId,
    required this.routeId,
    required this.activeBus,
    required this.selectedStop,
    required this.savedSelection,
    required this.isLoading,
    required this.onSaved,
  });

  final String profileId;
  final String routeId;
  final ActiveRouteBus? activeBus;
  final StudentRouteStop? selectedStop;
  final StudentStopSelection? savedSelection;
  final bool isLoading;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaving = ref.watch(studentStopSelectionSavingProvider(routeId));
    final selectedRadius = ref.watch(
      selectedStudentAlertRadiusProvider(routeId),
    );
    final radius = selectedRadius ?? savedSelection?.radiusMeters ?? 500;
    const radiusOptions = [100.0, 250.0, 500.0, 1000.0];
    final canSave =
        selectedStop != null &&
        activeBus?.busId != null &&
        !isSaving &&
        !isLoading;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected stop',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              selectedStop == null
                  ? 'Choose a stop to save it for this route.'
                  : selectedStop!.name,
            ),
            if (savedSelection != null) ...[
              const SizedBox(height: 6),
              Text(
                savedSelection!.enabled ? 'Alert enabled' : 'Alert disabled',
              ),
            ],
            if (activeBus == null) ...[
              const SizedBox(height: 6),
              const Text(
                'A stop can be saved when an active bus is available.',
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<double>(
              initialValue: radiusOptions.contains(radius) ? radius : 500,
              decoration: const InputDecoration(
                labelText: 'Alert radius',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final option in radiusOptions)
                  DropdownMenuItem(
                    value: option,
                    child: Text('${option.toInt()} metres'),
                  ),
              ],
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value != null) {
                        ref
                                .read(
                                  selectedStudentAlertRadiusProvider(
                                    routeId,
                                  ).notifier,
                                )
                                .state =
                            value;
                      }
                    },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canSave
                        ? () => _save(context, ref, activeBus!.busId!, radius)
                        : null,
                    icon: isSaving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bookmark_add_outlined),
                    label: Text(
                      savedSelection == null
                          ? 'Save stop'
                          : savedSelection!.enabled
                          ? 'Update stop'
                          : 'Enable alert',
                    ),
                  ),
                ),
                if (savedSelection != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: isSaving
                        ? null
                        : () => _toggleEnabled(
                            context,
                            ref,
                            savedSelection!.id,
                            !savedSelection!.enabled,
                          ),
                    icon: Icon(
                      savedSelection!.enabled
                          ? Icons.notifications_off_outlined
                          : Icons.notifications_active_outlined,
                    ),
                    tooltip: savedSelection!.enabled
                        ? 'Disable alert'
                        : 'Enable alert',
                  ),
                  IconButton(
                    onPressed: isSaving
                        ? null
                        : () => _remove(context, ref, savedSelection!.id),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove saved stop',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    String busId,
    double radius,
  ) async {
    ref.read(studentStopSelectionSavingProvider(routeId).notifier).state = true;
    try {
      final permissionGranted = await ref
          .read(studentNotificationServiceProvider)
          .initializeAndRequestPermission();
      await ref
          .read(studentStopSelectionRepositoryProvider)
          .save(
            profileId: profileId,
            stopId: selectedStop!.id,
            busId: busId,
            radiusMeters: radius,
          );
      onSaved();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              permissionGranted
                  ? 'Stop selection saved.'
                  : 'Stop saved, but notifications are not permitted.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the selected stop.')),
        );
      }
    } finally {
      ref.read(studentStopSelectionSavingProvider(routeId).notifier).state =
          false;
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    String selectionId,
  ) async {
    ref.read(studentStopSelectionSavingProvider(routeId).notifier).state = true;
    try {
      await ref
          .read(studentStopSelectionRepositoryProvider)
          .remove(profileId: profileId, selectionId: selectionId);
      ref.read(selectedStudentStopProvider(routeId).notifier).state = null;
      onSaved();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stop selection removed.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove the selected stop.')),
        );
      }
    } finally {
      ref.read(studentStopSelectionSavingProvider(routeId).notifier).state =
          false;
    }
  }

  Future<void> _toggleEnabled(
    BuildContext context,
    WidgetRef ref,
    String selectionId,
    bool enabled,
  ) async {
    ref.read(studentStopSelectionSavingProvider(routeId).notifier).state = true;
    try {
      await ref
          .read(studentStopSelectionRepositoryProvider)
          .setEnabled(
            profileId: profileId,
            selectionId: selectionId,
            enabled: enabled,
          );
      onSaved();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled ? 'Alert enabled.' : 'Alert disabled.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the alert.')),
        );
      }
    } finally {
      ref.read(studentStopSelectionSavingProvider(routeId).notifier).state =
          false;
    }
  }
}

class _EtaCard extends StatelessWidget {
  const _EtaCard({required this.tracking, required this.selectedStop});

  final AsyncValue<StudentLiveTracking?> tracking;
  final StudentRouteStop? selectedStop;

  @override
  Widget build(BuildContext context) {
    final message = tracking.when(
      loading: () => 'Loading ETA...',
      error: (_, _) => 'ETA unavailable right now.',
      data: (liveTracking) {
        if (selectedStop == null) {
          return 'Select a stop to calculate ETA.';
        }
        if (liveTracking == null) {
          return 'ETA unavailable: no active bus is available.';
        }
        final eta = StudentEtaCalculator.calculate(
          location: liveTracking.location,
          stop: selectedStop!,
        );
        return eta == null
            ? 'ETA unavailable: location, speed, or stop coordinates are missing.'
            : 'Approx. ${eta.roundedMinutes} min to ${selectedStop!.name}';
      },
    );
    return Card(
      child: ListTile(
        leading: const Icon(Icons.schedule_outlined),
        title: const Text('Estimated arrival'),
        subtitle: Text(message),
      ),
    );
  }
}

class _BusInformation extends StatelessWidget {
  const _BusInformation({
    required this.user,
    required this.routeId,
    required this.bus,
  });

  final AuthenticatedUser user;
  final String routeId;
  final ActiveRouteBus? bus;

  @override
  Widget build(BuildContext context) {
    if (bus == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.directions_bus_outlined),
          title: Text('No bus currently assigned'),
          subtitle: Text(
            'Bus information will appear when an active trip is available.',
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.directions_bus_filled_outlined),
              title: Text('${bus!.busNumber} • ${bus!.busName}'),
              subtitle: Text('Status: ${bus!.status}'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: bus!.busId == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StudentLiveTrackingPage(
                              user: user,
                              routeId: routeId,
                              busId: bus!.busId,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Track this bus'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({required this.onRetry});

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
              'We could not load this route.',
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
