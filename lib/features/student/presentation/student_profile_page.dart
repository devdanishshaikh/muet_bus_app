import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/authenticated_user.dart';
import '../../auth/presentation/auth_providers.dart';

/// Profile screen for the logged-in student.
///
/// Displays the student's identity information sourced from [AuthenticatedUser].
/// Sensitive fields (e.g. driver CNIC) are never shown here.
/// Deep profile editing will be added in a later step.
class StudentProfilePage extends ConsumerWidget {
  const StudentProfilePage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trimmedName = user.fullName.trim();
    final initials = trimmedName.isEmpty
        ? '?'
        : trimmedName
            .split(' ')
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      children: [
        // Avatar
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              initials,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Display name
        Text(
          user.fullName.isEmpty ? 'Student' : user.fullName,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // Info card
        Card(
          child: Column(
            children: [
              _ProfileRow(
                icon: Icons.badge_outlined,
                label: 'Role',
                value: 'Student',
              ),
              const Divider(height: 1, indent: 56),
              _ProfileRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: user.email.isEmpty ? '—' : user.email,
              ),
              if (user.relatedProfileId != null) ...[
                const Divider(height: 1, indent: 56),
                _ProfileRow(
                  icon: Icons.fingerprint,
                  label: 'Student record',
                  value: user.relatedProfileId!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Sign out
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(authControllerProvider.notifier).signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: theme.textTheme.labelMedium),
      subtitle: Text(value, style: theme.textTheme.bodyMedium),
    );
  }
}
