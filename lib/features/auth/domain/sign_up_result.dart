import 'authenticated_user.dart';

/// Outcome of a self-service registration attempt.
enum SignUpStatus {
  /// The account was created and is already signed in (email confirmation off).
  signedIn,

  /// The account was created but the email must be confirmed before signing in.
  emailConfirmationRequired,
}

class SignUpResult {
  const SignUpResult({required this.status, this.user});

  const SignUpResult.emailConfirmationRequired()
      : status = SignUpStatus.emailConfirmationRequired,
        user = null;

  final SignUpStatus status;

  /// Present only when [status] is [SignUpStatus.signedIn].
  final AuthenticatedUser? user;

  bool get requiresEmailConfirmation =>
      status == SignUpStatus.emailConfirmationRequired;
}
