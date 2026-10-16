import 'user_role.dart';

/// Pure, reusable validation rules for the sign-up form.
///
/// These mirror the server-side rules enforced by the `handle_new_user`
/// trigger, but exist so the UI can give immediate feedback.
abstract final class SignUpValidators {
  static const String studentEmailDomain = 'students.muet.edu.pk';

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _cnicPattern = RegExp(r'^\d{5}-\d{7}-\d$');

  static String? fullName(String? value) {
    if ((value ?? '').trim().length < 3) {
      return 'Enter your full name.';
    }
    return null;
  }

  static String? email(String? value, UserRole role) {
    final email = (value ?? '').trim();
    if (!_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    if (role == UserRole.student &&
        !email.toLowerCase().endsWith('@$studentEmailDomain')) {
      return 'Student accounts must use a @$studentEmailDomain address.';
    }
    return null;
  }

  static String? password(String? value) {
    if ((value ?? '').length < 8) {
      return 'Use at least 8 characters.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '') != password) {
      return 'Passwords do not match.';
    }
    return null;
  }

  static String? inviteCode(String? value, UserRole role) {
    if (role == UserRole.driver || role == UserRole.admin) {
      if ((value ?? '').trim().isEmpty) {
        return 'A provisioning code is required for this role.';
      }
    }
    return null;
  }

  static String? cnic(String? value, UserRole role) {
    if (role != UserRole.driver) {
      return null;
    }
    if (!_cnicPattern.hasMatch((value ?? '').trim())) {
      return 'Enter a valid CNIC (e.g. 12345-1234567-1).';
    }
    return null;
  }
}
