import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/environment.dart';
import '../data/auth_service.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/authenticated_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(Supabase.instance.client);
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(authRepositoryProvider));
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthenticatedUser?>(
      AuthController.new,
    );

class AuthController extends AsyncNotifier<AuthenticatedUser?> {
  late final AuthService _authService;

  @override
  Future<AuthenticatedUser?> build() async {
    if (!Environment.isConfigured) {
      return null;
    }

    _authService = ref.watch(authServiceProvider);
    final subscription = _authService.sessionChanges.listen((_) {
      ref.invalidateSelf();
    });
    ref.onDispose(subscription.cancel);

    return _authService.restoreSession();
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _authService.signIn(email: email, password: password),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _authService.signOut();
      return null;
    });
  }
}
