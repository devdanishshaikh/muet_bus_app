import 'user_role.dart';

/// Everything the backend needs to provision a new account.
///
/// The role is only a *request*: the database validates it (and any required
/// provisioning code) before assigning the final role.
class SignUpRequest {
  const SignUpRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
    this.inviteCode,
    this.studentId,
    this.cnic,
    this.phone,
  });

  final String email;
  final String password;
  final String fullName;
  final UserRole role;

  /// Required for [UserRole.driver] and [UserRole.admin].
  final String? inviteCode;

  /// Optional for [UserRole.student]; defaults to the email local part.
  final String? studentId;

  /// Required for [UserRole.driver].
  final String? cnic;

  /// Optional contact number.
  final String? phone;

  bool get requiresInviteCode =>
      role == UserRole.driver || role == UserRole.admin;

  bool get requiresCnic => role == UserRole.driver;

  bool get isStudent => role == UserRole.student;
}
