import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/authenticated_user.dart';
import '../auth_providers.dart';

class UnauthorizedPage extends ConsumerWidget {
  const UnauthorizedPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account configuration')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gpp_maybe_outlined, size: 56),
              const SizedBox(height: 16),
              const Text(
                'This account is not authorized for the application yet.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                user.role.name == 'unknown'
                    ? 'Ask a MUET administrator to configure your role.'
                    : 'Ask a MUET administrator to complete your profile.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
