import '../domain/auth_repository.dart';
import '../domain/authenticated_user.dart';
import '../domain/sign_up_request.dart';
import '../domain/sign_up_result.dart';
import '../domain/user_role.dart';

class AuthService {
  const AuthService(this._repository);

  final AuthRepository _repository;

  Stream<void> get sessionChanges => _repository.sessionChanges;

  Future<AuthenticatedUser?> restoreSession() {
    return _repository.restoreSession();
  }

  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) {
    return _repository.signIn(email: email, password: password);
  }

  Future<SignUpResult> signUp(SignUpRequest request) {
    return _repository.signUp(request);
  }

  Future<bool> validateProvisioningCode({
    required String code,
    required UserRole role,
  }) {
    return _repository.validateProvisioningCode(code: code, role: role);
  }

  Future<void> signOut() {
    return _repository.signOut();
  }
}
