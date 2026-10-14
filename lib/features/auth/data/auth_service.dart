import '../domain/auth_repository.dart';
import '../domain/authenticated_user.dart';

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

  Future<void> signOut() {
    return _repository.signOut();
  }
}
