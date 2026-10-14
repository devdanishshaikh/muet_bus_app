import 'authenticated_user.dart';

abstract interface class AuthRepository {
  Stream<void> get sessionChanges;

  Future<AuthenticatedUser?> restoreSession();

  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
