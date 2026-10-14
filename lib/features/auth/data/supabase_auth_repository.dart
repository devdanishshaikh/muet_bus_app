import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/authenticated_user.dart';
import '../domain/user_role.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<void> get sessionChanges {
    return _client.auth.onAuthStateChange.map((_) {});
  }

  @override
  Future<AuthenticatedUser?> restoreSession() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null || _client.auth.currentSession == null) {
      return null;
    }

    return _loadUser(authUser);
  }

  @override
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) {
        throw const AuthFailure('Unable to load the authenticated account.');
      }

      return _loadUser(authUser);
    } on AuthFailure {
      rethrow;
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    } catch (_) {
      throw const AuthFailure('Unable to sign in right now. Please try again.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    } catch (_) {
      throw const AuthFailure('Unable to sign out right now.');
    }
  }

  Future<AuthenticatedUser> _loadUser(User authUser) async {
    final profile = await _client
        .from('profiles')
        .select('id, full_name, email, role')
        .eq('id', authUser.id)
        .maybeSingle();

    if (profile == null) {
      return AuthenticatedUser(
        id: authUser.id,
        email: authUser.email ?? '',
        fullName: '',
        role: UserRole.unknown,
        profileComplete: false,
      );
    }

    final role = UserRole.fromValue(profile['role'] as String?);
    final profileId = profile['id'] as String;
    final email = profile['email'] as String? ?? authUser.email ?? '';
    final fullName = profile['full_name'] as String? ?? '';

    if (role == UserRole.student) {
      final student = await _client
          .from('students')
          .select('id')
          .eq('profile_id', profileId)
          .maybeSingle();
      return AuthenticatedUser(
        id: authUser.id,
        email: email,
        fullName: fullName,
        role: role,
        profileComplete: student != null,
        relatedProfileId: student?['id'] as String?,
      );
    }

    if (role == UserRole.driver) {
      final driver = await _client
          .from('drivers')
          .select('id, status')
          .eq('profile_id', profileId)
          .maybeSingle();
      return AuthenticatedUser(
        id: authUser.id,
        email: email,
        fullName: fullName,
        role: role,
        profileComplete: driver != null && driver['status'] == 'active',
        relatedProfileId: driver?['id'] as String?,
      );
    }

    return AuthenticatedUser(
      id: authUser.id,
      email: email,
      fullName: fullName,
      role: role,
      profileComplete: role == UserRole.admin,
    );
  }
}
