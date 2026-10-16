import 'authenticated_user.dart';
import 'sign_up_request.dart';
import 'sign_up_result.dart';
import 'user_role.dart';

abstract interface class AuthRepository {
  Stream<void> get sessionChanges;

  Future<AuthenticatedUser?> restoreSession();

  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  });

  /// Creates a new account. The final role is decided by the database.
  Future<SignUpResult> signUp(SignUpRequest request);

  /// Checks a driver/admin provisioning code before creating the account.
  Future<bool> validateProvisioningCode({
    required String code,
    required UserRole role,
  });

  Future<void> signOut();
}
