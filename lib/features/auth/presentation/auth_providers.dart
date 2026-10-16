import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/environment.dart';
import '../data/auth_service.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/authenticated_user.dart';
import '../domain/sign_up_request.dart';
import '../domain/sign_up_result.dart';
import '../domain/user_role.dart';

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
    _authService = ref.watch(authServiceProvider);

    if (!Environment.isConfigured) {
      return null;
    }

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

  /// Creates a new account.
  ///
  /// On success the state holds the signed-in user (or `null` while waiting for
  /// email confirmation). On failure the previous state is restored and the
  /// [AuthFailure] is thrown so the form can show it inline.
  Future<SignUpResult> signUp(SignUpRequest request) async {
    final previousState = state;
    state = const AsyncLoading();

    try {
      final result = await _authService.signUp(request);
      state = AsyncData(result.user);
      return result;
    } catch (error, stackTrace) {
      state = previousState;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<bool> validateProvisioningCode({
    required String code,
    required UserRole role,
  }) {
    return _authService.validateProvisioningCode(code: code, role: role);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _authService.signOut();
      return null;
    });
  }
}
