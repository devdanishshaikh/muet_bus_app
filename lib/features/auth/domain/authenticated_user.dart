import 'user_role.dart';

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.profileComplete,
    this.relatedProfileId,
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final bool profileComplete;
  final String? relatedProfileId;

  bool get isAuthorized => profileComplete && role != UserRole.unknown;
}
