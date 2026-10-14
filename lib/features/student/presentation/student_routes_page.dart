import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/authenticated_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/pages/unauthorized_page.dart';
import 'student_route_details_page.dart';
import 'student_routes_providers.dart';

class StudentRoutesPage extends ConsumerWidget {
  const StudentRoutesPage({required this.user, super.key});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role != UserRole.student) {
      return UnauthorizedPage(user: user);
    }

    final routesState = ref.watch(activeStudentRoutesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Routes')),
      body: routesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _RoutesError(
          onRetry: () => ref.invalidate(activeStudentRoutesProvider),
        ),
        data: (routes) {
          if (routes.isEmpty) {
            return const _RoutesEmpty();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeStudentRoutesProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: routes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final route = routes[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(child: Icon(Icons.alt_route)),
                    title: Text(route.name),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        route.description?.isNotEmpty == true
                            ? route.description!
                            : '${route.stops.length} stops',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StudentRouteDetailsPage(
                            user: user,
                            routeId: route.id,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RoutesEmpty extends StatelessWidget {
  const _RoutesEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No active routes are available right now.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _RoutesError extends StatelessWidget {
  const _RoutesError({required this.onRetry});

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
              'We could not load the routes.',
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
