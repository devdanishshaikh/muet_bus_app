import 'package:flutter/material.dart';

import '../../auth/domain/authenticated_user.dart';

/// Placeholder screen for My Alerts.
///
/// Full alert management (proximity alerts, push notification history, etc.)
/// will be implemented in a later step. This screen provides the navigation
/// anchor so the shell scaffold is complete now.
class StudentAlertsPage extends StatelessWidget {
  const StudentAlertsPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.notifications_none_outlined,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'My Alerts',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Proximity alerts for your saved bus stops will appear here. '
          'You can configure alerts when viewing a route\'s stops.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Alerts coming soon'),
            subtitle: const Text(
              'Visit a route\'s detail page and select a stop to save an alert.',
            ),
          ),
        ),
      ],
    );
  }
}
