import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/authenticated_user.dart';
import '../domain/sign_up_request.dart';
import '../domain/sign_up_result.dart';
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
  Future<SignUpResult> signUp(SignUpRequest request) async {
    try {
      final response = await _client.auth.signUp(
        email: request.email.trim(),
        password: request.password,
        data: <String, dynamic>{
          'full_name': request.fullName.trim(),
          'requested_role': request.role.name,
          if (request.requiresInviteCode)
            'invite_code': request.inviteCode?.trim(),
          if (request.isStudent &&
              (request.studentId?.trim().isNotEmpty ?? false))
            'student_id': request.studentId!.trim(),
          if (request.requiresCnic) 'cnic': request.cnic?.trim(),
          if (request.phone?.trim().isNotEmpty ?? false)
            'phone': request.phone!.trim(),
        },
      );

      final authUser = response.user;
      if (authUser == null) {
        throw const AuthFailure(
          'Unable to create the account. Please try again.',
        );
      }

      if (response.session == null) {
        return const SignUpResult.emailConfirmationRequired();
      }

      return SignUpResult(
        status: SignUpStatus.signedIn,
        user: await _loadUser(authUser),
      );
    } on AuthFailure {
      rethrow;
    } on AuthException catch (error) {
      throw AuthFailure(_signUpFailureMessage(error));
    } catch (_) {
      throw const AuthFailure(
        'Unable to create the account right now. Please try again.',
      );
    }
  }

  @override
  Future<bool> validateProvisioningCode({
    required String code,
    required UserRole role,
  }) async {
    try {
      final result = await _client.rpc(
        'is_provisioning_code_valid',
        params: <String, dynamic>{'p_code': code, 'p_role': role.name},
      );
      return result == true;
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    } catch (_) {
      throw const AuthFailure('Unable to verify the provisioning code.');
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

  String _signUpFailureMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('already registered') ||
        message.contains('already been registered') ||
        error.code == 'user_already_exists') {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (message.contains('provisioning code') ||
        message.contains('cnic') ||
        message.contains('students.muet.edu.pk')) {
      return error.message;
    }
    if (message.contains('database error') ||
        message.contains('saving new user')) {
      return 'We could not create the account. Check the provisioning code and your details, then try again.';
    }
    return error.message;
  }
}
