import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/authenticated_user.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/user_role.dart';

void main() {
  group('UserRole', () {
    test('parses supported roles', () {
      expect(UserRole.fromValue('student'), UserRole.student);
      expect(UserRole.fromValue('driver'), UserRole.driver);
      expect(UserRole.fromValue('admin'), UserRole.admin);
    });

    test('rejects missing or unsupported roles', () {
      expect(UserRole.fromValue(null), UserRole.unknown);
      expect(UserRole.fromValue('operator'), UserRole.unknown);
    });
  });

  group('AuthenticatedUser', () {
    test('requires a complete profile and known role', () {
      const user = AuthenticatedUser(
        id: 'user-id',
        email: 'student@muet.edu.pk',
        fullName: 'Student',
        role: UserRole.student,
        profileComplete: true,
      );

      expect(user.isAuthorized, isTrue);
    });

    test('rejects incomplete or unknown accounts', () {
      const incomplete = AuthenticatedUser(
        id: 'user-id',
        email: 'student@muet.edu.pk',
        fullName: 'Student',
        role: UserRole.student,
        profileComplete: false,
      );
      const unknown = AuthenticatedUser(
        id: 'user-id',
        email: 'unknown@muet.edu.pk',
        fullName: 'Unknown',
        role: UserRole.unknown,
        profileComplete: false,
      );

      expect(incomplete.isAuthorized, isFalse);
      expect(unknown.isAuthorized, isFalse);
    });
  });
}
