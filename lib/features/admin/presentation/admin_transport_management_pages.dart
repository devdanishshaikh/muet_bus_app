import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/authenticated_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/pages/unauthorized_page.dart';
import '../domain/admin_transport_management_data.dart';
import 'admin_dashboard_providers.dart';

class AdminBusManagementPage extends ConsumerWidget {
  const AdminBusManagementPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.admin) return UnauthorizedPage(user: user);
    final buses = ref.watch(adminBusesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bus Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBusEditor(context, ref),
        tooltip: 'Add bus',
        child: const Icon(Icons.add),
      ),
      body: buses.when(
        loading: _loading,
        error: (error, stackTrace) => _ErrorState(
          onRetry: () => ref.invalidate(adminBusesProvider),
        ),
        data: (data) => data.isEmpty
            ? const _EmptyState(message: 'No buses have been added yet.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: data.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final bus = data[index];
                  return ListTile(
                    leading: const Icon(Icons.directions_bus_outlined),
                    title: Text(bus.busNumber),
                    subtitle: Text('${bus.busName}\nStatus: ${bus.status}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _showBusEditor(context, ref, bus),
                  );
                },
              ),
      ),
    );
  }
}

class AdminDriverManagementPage extends ConsumerWidget {
  const AdminDriverManagementPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.admin) return UnauthorizedPage(user: user);
    final drivers = ref.watch(adminDriversProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Management')),
      body: drivers.when(
        loading: _loading,
        error: (error, stackTrace) => _ErrorState(
          onRetry: () => ref.invalidate(adminDriversProvider),
        ),
        data: (data) => data.isEmpty
            ? const _EmptyState(message: 'No drivers are available yet.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: data.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final driver = data[index];
                  return ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(driver.name),
                    subtitle: Text(
                      '${driver.phone ?? 'No phone number'}\nStatus: ${driver.status}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _showDriverStatusEditor(context, ref, driver),
                  );
                },
              ),
      ),
    );
  }
}

class AdminRouteManagementPage extends ConsumerWidget {
  const AdminRouteManagementPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.admin) return UnauthorizedPage(user: user);
    final routes = ref.watch(adminRoutesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Route Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRouteEditor(context, ref),
        tooltip: 'Add route',
        child: const Icon(Icons.add),
      ),
      body: routes.when(
        loading: _loading,
        error: (error, stackTrace) => _ErrorState(
          onRetry: () => ref.invalidate(adminRoutesProvider),
        ),
        data: (data) => data.isEmpty
            ? const _EmptyState(message: 'No routes have been added yet.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: data.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final route = data[index];
                  return ListTile(
                    leading: const Icon(Icons.route_outlined),
                    title: Text(route.name),
                    subtitle: Text(
                      '${route.description ?? 'No description'}\nStatus: ${route.status}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit route',
                      onPressed: () => _showRouteEditor(context, ref, route),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminStopsManagementPage(
                          user: user,
                          route: route,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class AdminStopsManagementPage extends ConsumerWidget {
  const AdminStopsManagementPage({
    required this.user,
    required this.route,
    super.key,
  });

  final AuthenticatedUser user;
  final AdminRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.admin) return UnauthorizedPage(user: user);
    final stops = ref.watch(adminStopsProvider(route.id!));
    return Scaffold(
      appBar: AppBar(title: Text('${route.name} Stops')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStopEditor(context, ref, route),
        tooltip: 'Add stop',
        child: const Icon(Icons.add),
      ),
      body: stops.when(
        loading: _loading,
        error: (error, stackTrace) => _ErrorState(
          onRetry: () => ref.invalidate(adminStopsProvider(route.id!)),
        ),
        data: (data) => data.isEmpty
            ? const _EmptyState(message: 'No stops have been added to this route.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: data.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final stop = data[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${stop.stopOrder}')),
                    title: Text(stop.name),
                    subtitle: Text(
                      '${stop.latitude.toStringAsFixed(6)}, ${stop.longitude.toStringAsFixed(6)}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _showStopEditor(context, ref, route, stop),
                  );
                },
              ),
      ),
    );
  }
}

class AdminBusDriverAssignmentsPage extends ConsumerWidget {
  const AdminBusDriverAssignmentsPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.admin) return UnauthorizedPage(user: user);
    final assignments = ref.watch(adminBusDriverAssignmentsProvider);
    final buses = ref.watch(adminBusesProvider);
    final drivers = ref.watch(adminDriversProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bus Assignments')),
      floatingActionButton: FloatingActionButton(
        onPressed: buses.hasValue && drivers.hasValue
            ? () => _showBusDriverAssignmentEditor(
                context,
                ref,
                buses.requireValue,
                drivers.requireValue,
              )
            : null,
        tooltip: 'Assign driver',
        child: const Icon(Icons.add),
      ),
      body: _assignmentBody(
        values: [assignments, buses, drivers],
        onRetry: () {
          ref.invalidate(adminBusDriverAssignmentsProvider);
          ref.invalidate(adminBusesProvider);
          ref.invalidate(adminDriversProvider);
        },
        child: assignments.hasValue && assignments.requireValue.isEmpty
            ? const _EmptyState(message: 'No bus-driver assignments yet.')
            : assignments.hasValue
            ? ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: assignments.requireValue.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final assignment = assignments.requireValue[index];
                  return ListTile(
                    leading: Icon(
                      assignment.active
                          ? Icons.assignment_ind
                          : Icons.assignment_ind_outlined,
                    ),
                    title: Text('${assignment.busName} - ${assignment.driverName}'),
                    subtitle: Text(assignment.active ? 'Active' : 'Inactive'),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: buses.hasValue && drivers.hasValue
                        ? () => _showBusDriverAssignmentEditor(
                            context,
                            ref,
                            buses.requireValue,
                            drivers.requireValue,
                            assignment: assignment,
                          )
                        : null,
                  );
                },
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class AdminBusRouteAssignmentsPage extends ConsumerWidget {
  const AdminBusRouteAssignmentsPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.admin) return UnauthorizedPage(user: user);
    final assignments = ref.watch(adminBusRouteAssignmentsProvider);
    final buses = ref.watch(adminBusesProvider);
    final routes = ref.watch(adminRoutesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Route Assignments')),
      floatingActionButton: FloatingActionButton(
        onPressed: buses.hasValue && routes.hasValue
            ? () => _showBusRouteAssignmentEditor(
                context,
                ref,
                buses.requireValue,
                routes.requireValue,
              )
            : null,
        tooltip: 'Assign route',
        child: const Icon(Icons.add),
      ),
      body: _assignmentBody(
        values: [assignments, buses, routes],
        onRetry: () {
          ref.invalidate(adminBusRouteAssignmentsProvider);
          ref.invalidate(adminBusesProvider);
          ref.invalidate(adminRoutesProvider);
        },
        child: assignments.hasValue && assignments.requireValue.isEmpty
            ? const _EmptyState(message: 'No bus-route assignments yet.')
            : assignments.hasValue
            ? ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: assignments.requireValue.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final assignment = assignments.requireValue[index];
                  return ListTile(
                    leading: Icon(
                      assignment.active
                          ? Icons.alt_route
                          : Icons.alt_route_outlined,
                    ),
                    title: Text('${assignment.busName} - ${assignment.routeName}'),
                    subtitle: Text(assignment.active ? 'Active' : 'Inactive'),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: buses.hasValue && routes.hasValue
                        ? () => _showBusRouteAssignmentEditor(
                            context,
                            ref,
                            buses.requireValue,
                            routes.requireValue,
                            assignment: assignment,
                          )
                        : null,
                  );
                },
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class AdminRouteSchedulesPage extends ConsumerWidget {
  const AdminRouteSchedulesPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.admin) return UnauthorizedPage(user: user);
    final schedules = ref.watch(adminRouteSchedulesProvider);
    final routes = ref.watch(adminRoutesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Route Schedules')),
      floatingActionButton: FloatingActionButton(
        onPressed: routes.hasValue
            ? () => _showScheduleEditor(context, ref, routes.requireValue)
            : null,
        tooltip: 'Add schedule',
        child: const Icon(Icons.add),
      ),
      body: _assignmentBody(
        values: [schedules, routes],
        onRetry: () {
          ref.invalidate(adminRouteSchedulesProvider);
          ref.invalidate(adminRoutesProvider);
        },
        child: schedules.hasValue && schedules.requireValue.isEmpty
            ? const _EmptyState(message: 'No route schedules have been added yet.')
            : schedules.hasValue
            ? ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: schedules.requireValue.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final schedule = schedules.requireValue[index];
                  return ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text('${schedule.routeName} - ${schedule.stopName}'),
                    subtitle: Text(
                      '${_dayName(schedule.dayOfWeek)} at ${schedule.scheduledTime}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: routes.hasValue
                        ? () => _showScheduleEditor(
                            context,
                            ref,
                            routes.requireValue,
                            schedule: schedule,
                          )
                        : null,
                  );
                },
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

Widget _loading() => const Center(child: CircularProgressIndicator());

Widget _assignmentBody({
  required List<AsyncValue<Object>> values,
  required VoidCallback onRetry,
  required Widget child,
}) {
  if (values.any((value) => value.isLoading)) return _loading();
  if (values.any((value) => value.hasError)) return _ErrorState(onRetry: onRetry);
  return child;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('We could not load this admin section.', textAlign: TextAlign.center),
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

Future<void> _showBusEditor(
  BuildContext context,
  WidgetRef ref, [
  AdminBus? bus,
]) async {
  final number = TextEditingController(text: bus?.busNumber);
  final name = TextEditingController(text: bus?.busName);
  var status = bus?.status ?? 'inactive';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(bus == null ? 'Add bus' : 'Edit bus'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: number, decoration: const InputDecoration(labelText: 'Bus number')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Bus name')),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const ['active', 'inactive', 'delayed', 'maintenance']
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(() => status = value!),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (number.text.trim().isEmpty || name.text.trim().isEmpty) return;
              if (bus?.status == 'active' && status != 'active' &&
                  !await _confirm(context, 'Change bus status?', 'This will deactivate the currently active bus status.')) {
                return;
              }
              try {
                await ref.read(adminTransportManagementRepositoryProvider).saveBus(
                  AdminBus(id: bus?.id, busNumber: number.text.trim(), busName: name.text.trim(), status: status),
                );
                ref.invalidate(adminBusesProvider);
                ref.invalidate(adminDashboardProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) _success(context, 'Bus saved.');
              } catch (_) {
                if (context.mounted) _failure(context, 'Could not save the bus.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  number.dispose();
  name.dispose();
}

Future<void> _showDriverStatusEditor(
  BuildContext context,
  WidgetRef ref,
  AdminDriver driver,
) async {
  var status = driver.status;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Update ${driver.name}'),
        content: DropdownButtonFormField<String>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Driver status'),
          items: const ['active', 'inactive', 'suspended']
              .map((value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: (value) => setState(() => status = value!),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (status != driver.status && driver.status == 'active' &&
                  !await _confirm(context, 'Change driver status?', 'This will make the driver unavailable for active work.')) {
                return;
              }
              try {
                await ref.read(adminTransportManagementRepositoryProvider).updateDriverStatus(driver.id, status);
                ref.invalidate(adminDriversProvider);
                ref.invalidate(adminDashboardProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) _success(context, 'Driver status updated.');
              } catch (_) {
                if (context.mounted) _failure(context, 'Could not update driver status.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showRouteEditor(
  BuildContext context,
  WidgetRef ref, [
  AdminRoute? route,
]) async {
  final name = TextEditingController(text: route?.name);
  final description = TextEditingController(text: route?.description);
  var status = route?.status ?? 'active';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(route == null ? 'Add route' : 'Edit route'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Route name')),
            TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const ['active', 'inactive']
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(() => status = value!),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              if (route?.status == 'active' && status == 'inactive' &&
                  !await _confirm(context, 'Deactivate route?', 'This route will no longer be active.')) {
                return;
              }
              try {
                await ref.read(adminTransportManagementRepositoryProvider).saveRoute(
                  AdminRoute(id: route?.id, name: name.text.trim(), description: description.text.trim().isEmpty ? null : description.text.trim(), status: status),
                );
                ref.invalidate(adminRoutesProvider);
                ref.invalidate(adminDashboardProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) _success(context, 'Route saved.');
              } catch (_) {
                if (context.mounted) _failure(context, 'Could not save the route.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  description.dispose();
}

Future<void> _showStopEditor(
  BuildContext context,
  WidgetRef ref,
  AdminRoute route, [
  AdminStop? stop,
]) async {
  final name = TextEditingController(text: stop?.name);
  final latitude = TextEditingController(text: stop?.latitude.toString());
  final longitude = TextEditingController(text: stop?.longitude.toString());
  final order = TextEditingController(text: stop?.stopOrder.toString());
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(stop == null ? 'Add stop' : 'Edit stop'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Stop name')),
          TextField(
            controller: latitude,
            decoration: const InputDecoration(labelText: 'Latitude'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          ),
          TextField(
            controller: longitude,
            decoration: const InputDecoration(labelText: 'Longitude'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          ),
          TextField(
            controller: order,
            decoration: const InputDecoration(labelText: 'Stop order'),
            keyboardType: TextInputType.number,
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final parsedLatitude = double.tryParse(latitude.text.trim());
            final parsedLongitude = double.tryParse(longitude.text.trim());
            final parsedOrder = int.tryParse(order.text.trim());
            if (name.text.trim().isEmpty || parsedLatitude == null || parsedLongitude == null || parsedOrder == null || parsedOrder < 1) return;
            try {
              await ref.read(adminTransportManagementRepositoryProvider).saveStop(
                AdminStop(
                  id: stop?.id,
                  routeId: route.id!,
                  name: name.text.trim(),
                  latitude: parsedLatitude,
                  longitude: parsedLongitude,
                  stopOrder: parsedOrder,
                ),
              );
              ref.invalidate(adminStopsProvider(route.id!));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) _success(context, 'Stop saved.');
            } catch (_) {
              if (context.mounted) _failure(context, 'Could not save the stop.');
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  name.dispose();
  latitude.dispose();
  longitude.dispose();
  order.dispose();
}

Future<void> _showBusDriverAssignmentEditor(
  BuildContext context,
  WidgetRef ref,
  List<AdminBus> buses,
  List<AdminDriver> drivers, {
  AdminBusDriverAssignment? assignment,
}) async {
  if (buses.isEmpty || drivers.isEmpty) {
    _failure(context, 'Add a bus and a driver before creating an assignment.');
    return;
  }
  var busId = assignment?.busId ?? buses.first.id!;
  var driverId = assignment?.driverId ?? drivers.first.id;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Assign driver to bus'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: busId,
            decoration: const InputDecoration(labelText: 'Bus'),
            items: buses.map((bus) => DropdownMenuItem(value: bus.id, child: Text('${bus.busNumber} - ${bus.busName}'))).toList(),
            onChanged: (value) => setState(() => busId = value!),
          ),
          DropdownButtonFormField<String>(
            initialValue: driverId,
            decoration: const InputDecoration(labelText: 'Driver'),
            items: drivers.map((driver) => DropdownMenuItem(value: driver.id, child: Text(driver.name))).toList(),
            onChanged: (value) => setState(() => driverId = value!),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!await _confirm(context, 'Confirm driver assignment?', 'Any active assignment for this bus or driver will be deactivated.')) return;
              try {
                await ref.read(adminTransportManagementRepositoryProvider).assignDriverToBus(busId: busId, driverId: driverId);
                ref.invalidate(adminBusDriverAssignmentsProvider);
                ref.invalidate(adminDashboardProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) _success(context, 'Driver assignment saved.');
              } catch (_) {
                if (context.mounted) _failure(context, 'Could not save the driver assignment.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showBusRouteAssignmentEditor(
  BuildContext context,
  WidgetRef ref,
  List<AdminBus> buses,
  List<AdminRoute> routes, {
  AdminBusRouteAssignment? assignment,
}) async {
  if (buses.isEmpty || routes.isEmpty) {
    _failure(context, 'Add a bus and a route before creating an assignment.');
    return;
  }
  var busId = assignment?.busId ?? buses.first.id!;
  var routeId = assignment?.routeId ?? routes.first.id!;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Assign route to bus'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: busId,
            decoration: const InputDecoration(labelText: 'Bus'),
            items: buses.map((bus) => DropdownMenuItem(value: bus.id, child: Text('${bus.busNumber} - ${bus.busName}'))).toList(),
            onChanged: (value) => setState(() => busId = value!),
          ),
          DropdownButtonFormField<String>(
            initialValue: routeId,
            decoration: const InputDecoration(labelText: 'Route'),
            items: routes.map((route) => DropdownMenuItem(value: route.id, child: Text(route.name))).toList(),
            onChanged: (value) => setState(() => routeId = value!),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!await _confirm(context, 'Confirm route assignment?', 'The active route assignment for this bus will be deactivated.')) return;
              try {
                await ref.read(adminTransportManagementRepositoryProvider).assignRouteToBus(busId: busId, routeId: routeId);
                ref.invalidate(adminBusRouteAssignmentsProvider);
                ref.invalidate(adminDashboardProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) _success(context, 'Route assignment saved.');
              } catch (_) {
                if (context.mounted) _failure(context, 'Could not save the route assignment.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showScheduleEditor(
  BuildContext context,
  WidgetRef ref,
  List<AdminRoute> routes, {
  AdminRouteSchedule? schedule,
}) async {
  if (routes.isEmpty) {
    _failure(context, 'Add a route before creating a schedule.');
    return;
  }
  var routeId = schedule?.routeId ?? routes.first.id!;
  var stops = await ref.read(adminTransportManagementRepositoryProvider).loadStops(routeId);
  var stopId = schedule?.stopId ?? (stops.isEmpty ? null : stops.first.id);
  var day = schedule?.dayOfWeek ?? 0;
  final time = TextEditingController(text: schedule?.scheduledTime ?? '08:00:00');
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(schedule == null ? 'Add route schedule' : 'Edit route schedule'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: routeId,
              decoration: const InputDecoration(labelText: 'Route'),
              items: routes.map((route) => DropdownMenuItem(value: route.id, child: Text(route.name))).toList(),
              onChanged: (value) async {
                if (value == null) return;
                final loadedStops = await ref.read(adminTransportManagementRepositoryProvider).loadStops(value);
                setState(() {
                  routeId = value;
                  stops = loadedStops;
                  stopId = stops.isEmpty ? null : stops.first.id;
                });
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: stopId,
              decoration: const InputDecoration(labelText: 'Stop'),
              items: stops.map((stop) => DropdownMenuItem(value: stop.id, child: Text('${stop.stopOrder}. ${stop.name}'))).toList(),
              onChanged: stops.isEmpty ? null : (value) => setState(() => stopId = value),
            ),
            DropdownButtonFormField<int>(
              initialValue: day,
              decoration: const InputDecoration(labelText: 'Day of week'),
              items: List.generate(7, (index) => DropdownMenuItem(value: index, child: Text(_dayName(index)))),
              onChanged: (value) => setState(() => day = value!),
            ),
            TextField(controller: time, decoration: const InputDecoration(labelText: 'Scheduled time (HH:MM:SS)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: stopId == null
                ? null
                : () async {
                    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$').hasMatch(time.text.trim())) return;
                    try {
                      await ref.read(adminTransportManagementRepositoryProvider).saveRouteSchedule(
                        AdminRouteSchedule(
                          id: schedule?.id,
                          routeId: routeId,
                          routeName: '',
                          stopId: stopId!,
                          stopName: '',
                          dayOfWeek: day,
                          scheduledTime: time.text.trim().length == 5 ? '${time.text.trim()}:00' : time.text.trim(),
                        ),
                      );
                      ref.invalidate(adminRouteSchedulesProvider);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (context.mounted) _success(context, 'Route schedule saved.');
                    } catch (_) {
                      if (context.mounted) _failure(context, 'Could not save the route schedule.');
                    }
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  time.dispose();
}

Future<bool> _confirm(BuildContext context, String title, String message) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm')),
          ],
        ),
      ) ??
      false;
}

void _success(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void _failure(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _dayName(int day) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][day];
