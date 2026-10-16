import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/authenticated_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/pages/unauthorized_page.dart';
import '../domain/student_route.dart';
import '../domain/student_stop_selection.dart';
import 'student_routes_providers.dart';
import 'student_stop_selection_providers.dart';

class StudentAlertFormPage extends ConsumerStatefulWidget {
  const StudentAlertFormPage({
    required this.user,
    this.existingAlert,
    super.key,
  });

  final AuthenticatedUser user;
  final StudentStopSelection? existingAlert;

  @override
  ConsumerState<StudentAlertFormPage> createState() => _StudentAlertFormPageState();
}

class _StudentAlertFormPageState extends ConsumerState<StudentAlertFormPage> {
  String? _selectedBusId;
  String? _selectedStopId;
  double _selectedRadius = 500;
  bool _isLoading = false;
  bool _showBusError = false;
  bool _showStopError = false;

  static const _radiusOptions = [250.0, 500.0, 1000.0];

  @override
  void initState() {
    super.initState();
    if (widget.existingAlert != null) {
      _selectedBusId = widget.existingAlert!.busId;
      _selectedStopId = widget.existingAlert!.stopId;
      _selectedRadius = widget.existingAlert!.radiusMeters;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.role != UserRole.student) {
      return UnauthorizedPage(user: widget.user);
    }

    final routesState = ref.watch(activeStudentRoutesWithBusesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingAlert == null ? 'Create alert' : 'Edit alert'),
      ),
      body: routesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _FormError(
          message: 'Could not load routes.',
          onRetry: () => ref.invalidate(activeStudentRoutesWithBusesProvider),
        ),
        data: (routeDetails) => _buildForm(context, routeDetails),
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<StudentRouteDetails> routeDetails) {
    // Collect all buses from active routes with active buses
    final buses = <String, _BusInfo>{};
    for (final detail in routeDetails) {
      if (detail.activeBus != null) {
        buses[detail.activeBus!.busId!] = _BusInfo(
          busId: detail.activeBus!.busId!,
          busNumber: detail.activeBus!.busNumber,
          busName: detail.activeBus!.busName,
          routeId: detail.route.id,
          routeName: detail.route.name,
        );
      }
    }

    final busList = buses.values.toList();

    // Filter stops for selected bus
    List<StudentRouteStop> stops = [];
    if (_selectedBusId != null) {
      final busInfo = buses[_selectedBusId];
      if (busInfo != null) {
        final detail = routeDetails.firstWhere((r) => r.route.id == busInfo.routeId);
        stops = detail.route.stops;
      }
    }

    return Form(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Select a bus',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedBusId,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Choose a bus',
              errorText: _showBusError ? 'Please select a bus' : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            items: busList.map((bus) {
              return DropdownMenuItem<String>(
                value: bus.busId,
                child: Text('${bus.busNumber} • ${bus.busName} (${bus.routeName})'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBusId = value;
                _selectedStopId = null;
                _showBusError = false;
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Select a stop',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedStopId,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Choose a stop',
              errorText: _showStopError ? 'Please select a stop' : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            items: stops.map((stop) {
              return DropdownMenuItem<String>(
                value: stop.id,
                child: Text('${stop.name} (Stop ${stop.stopOrder})'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedStopId = value;
                _showStopError = false;
              });
            },
          ),
          if (stops.isEmpty && _selectedBusId != null) ...[
            const SizedBox(height: 8),
            Text(
              'No stops available for this bus',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Alert radius',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<double>(
            initialValue: _selectedRadius,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            items: _radiusOptions.map((radius) {
              return DropdownMenuItem<double>(
                value: radius,
                child: Text('${(radius / 1000).toStringAsFixed(1)} km'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedRadius = value);
              }
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(widget.existingAlert == null ? 'Create alert' : 'Save changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _showBusError = _selectedBusId == null;
      _showStopError = _selectedStopId == null;
      _isLoading = true;
    });

    if (_selectedBusId == null || _selectedStopId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final repo = ref.read(studentStopSelectionRepositoryProvider);
      await repo.save(
        profileId: widget.user.id,
        stopId: _selectedStopId!,
        busId: _selectedBusId!,
        radiusMeters: _selectedRadius,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingAlert == null ? 'Alert created' : 'Alert updated'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}

class _BusInfo {
  const _BusInfo({
    required this.busId,
    required this.busNumber,
    required this.busName,
    required this.routeId,
    required this.routeName,
  });

  final String busId;
  final String busNumber;
  final String busName;
  final String routeId;
  final String routeName;
}

class _FormError extends StatelessWidget {
  const _FormError({required this.message, required this.onRetry});

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