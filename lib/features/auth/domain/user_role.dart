enum UserRole {
  student,
  driver,
  admin,
  unknown;

  factory UserRole.fromValue(String? value) {
    return switch (value?.toLowerCase()) {
      'student' => UserRole.student,
      'driver' => UserRole.driver,
      'admin' => UserRole.admin,
      _ => UserRole.unknown,
    };
  }
}
