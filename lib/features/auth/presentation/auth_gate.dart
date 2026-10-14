import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/environment.dart';
import '../../admin/presentation/admin_dashboard_page.dart';
import '../../driver/presentation/driver_dashboard_page.dart';
import '../../student/presentation/student_shell_page.dart';
import '../domain/auth_failure.dart';
import '../domain/authenticated_user.dart';
import '../domain/user_role.dart';
import 'auth_providers.dart';
import 'pages/auth_configuration_page.dart';
import 'pages/auth_loading_page.dart';
import 'pages/login_page.dart';
import 'pages/unauthorized_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Environment.isConfigured) {
      return const AuthConfigurationPage();
    }

    final authState = ref.watch(authControllerProvider);
    return authState.when(
      loading: () => const AuthLoadingPage(),
      error: (error, _) => LoginPage(errorMessage: _errorMessage(error)),
      data: (user) => _authenticatedContent(user),
    );
  }

  Widget _authenticatedContent(AuthenticatedUser? user) {
    if (user == null) {
      return const LoginPage();
    }

    if (!user.isAuthorized) {
      return UnauthorizedPage(user: user);
    }

    return switch (user.role) {
      UserRole.student => StudentShellPage(user: user),
      UserRole.driver => DriverDashboardPage(user: user),
      UserRole.admin => AdminDashboardPage(user: user),
      UserRole.unknown => UnauthorizedPage(user: user),
    };
  }

  String _errorMessage(Object error) {
    if (error is AuthFailure) {
      return error.message;
    }
    return 'Unable to authenticate. Please try again.';
  }
}
