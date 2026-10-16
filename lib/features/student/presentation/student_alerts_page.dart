import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/authenticated_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/pages/unauthorized_page.dart';
import '../domain/student_stop_selection.dart';
import 'student_alert_form_page.dart';
import 'student_stop_selection_providers.dart';

class StudentAlertsPage extends ConsumerWidget {
  const StudentAlertsPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.student) {
      return UnauthorizedPage(user: user);
    }

    final alertsState = ref.watch(studentStopSelectionsProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Alerts'),
        actions: [
          IconButton(
            onPressed: () => _navigateToCreateAlert(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Create alert',
          ),
        ],
      ),
      body: alertsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AlertsError(
          message: 'Could not load your alerts.',
          onRetry: () => ref.invalidate(studentStopSelectionsProvider(user.id)),
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return _EmptyAlertsState(onCreateAlert: () => _navigateToCreateAlert(context, ref));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(studentStopSelectionsProvider(user.id)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _AlertCard(
                alert: alerts[index],
                onToggle: (enabled) => _toggleAlert(context, ref, alerts[index], enabled),
                onDelete: () => _deleteAlert(context, ref, alerts[index]),
                onTap: () => _navigateToEditAlert(context, ref, alerts[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _navigateToCreateAlert(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentAlertFormPage(user: user),
      ),
    ).then((_) => ref.invalidate(studentStopSelectionsProvider(user.id)));
  }

  void _navigateToEditAlert(BuildContext context, WidgetRef ref, StudentStopSelection alert) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentAlertFormPage(user: user, existingAlert: alert),
      ),
    ).then((_) => ref.invalidate(studentStopSelectionsProvider(user.id)));
  }

  Future<void> _toggleAlert(
    BuildContext context,
    WidgetRef ref,
    StudentStopSelection alert,
    bool enabled,
  ) async {
    final repo = ref.read(studentStopSelectionRepositoryProvider);
    try {
      await repo.setEnabled(
        profileId: user.id,
        selectionId: alert.id,
        enabled: enabled,
      );
      if (!context.mounted) return;
      ref.invalidate(studentStopSelectionsProvider(user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(enabled ? 'Alert enabled' : 'Alert disabled')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update alert')),
      );
    }
  }

  Future<void> _deleteAlert(BuildContext context, WidgetRef ref, StudentStopSelection alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete alert?'),
        content: const Text('This will permanently remove this alert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final repo = ref.read(studentStopSelectionRepositoryProvider);
    try {
      await repo.remove(profileId: user.id, selectionId: alert.id);
      if (!context.mounted) return;
      ref.invalidate(studentStopSelectionsProvider(user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert deleted')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete alert')),
      );
    }
  }
}

class _EmptyAlertsState extends StatelessWidget {
  const _EmptyAlertsState({required this.onCreateAlert});

  final VoidCallback onCreateAlert;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_none_outlined,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'No alerts yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Create an alert to get notified when your bus approaches a stop.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: onCreateAlert,
                  icon: const Icon(Icons.add),
                  label: const Text('Create your first alert'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsError extends StatelessWidget {
  const _AlertsError({required this.message, required this.onRetry});

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

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });

  final StudentStopSelection alert;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${alert.busNumber} • ${alert.busName}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stop: ${alert.stopName}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (alert.routeName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Route: ${alert.routeName}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Switch(
                        value: alert.enabled,
                        onChanged: onToggle,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onDelete,
                        tooltip: 'Delete alert',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Radius: ${(alert.radiusMeters / 1000).toStringAsFixed(1)} km',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  const Spacer(),
                  if (alert.triggeredAt != null) ...[
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Triggered ${_formatDateTime(alert.triggeredAt!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ] else ...[
                    Text(
                      alert.enabled ? 'Active' : 'Disabled',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: alert.enabled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    return value.toLocal().toString().split('.').first;
  }
}