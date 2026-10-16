import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/auth_repository.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/authenticated_user.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/sign_up_request.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/sign_up_result.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/sign_up_validators.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/domain/user_role.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/presentation/auth_providers.dart';
import 'package:muet_smart_bus_tracking_system/features/auth/presentation/pages/sign_up_page.dart';

void main() {
  group('SignUpValidators', () {
    test('student email must be on the student domain', () {
      expect(
        SignUpValidators.email('23cs092@students.muet.edu.pk', UserRole.student),
        isNull,
      );
      expect(
        SignUpValidators.email('23cs092@muet.edu.pk', UserRole.student),
        isNotNull,
      );
    });

    test('driver and admin accept a normal email address', () {
      expect(
        SignUpValidators.email('transport@muet.edu.pk', UserRole.admin),
        isNull,
      );
      expect(
        SignUpValidators.email('transport@muet.edu.pk', UserRole.driver),
        isNull,
      );
      expect(SignUpValidators.email('not-an-email', UserRole.admin), isNotNull);
    });

    test('provisioning code is required for driver and admin only', () {
      expect(SignUpValidators.inviteCode(null, UserRole.admin), isNotNull);
      expect(SignUpValidators.inviteCode('  ', UserRole.driver), isNotNull);
      expect(SignUpValidators.inviteCode('MUET-DRIVER-2026', UserRole.driver), isNull);
      expect(SignUpValidators.inviteCode(null, UserRole.student), isNull);
    });

    test('cnic is validated for drivers and ignored for other roles', () {
      expect(
        SignUpValidators.cnic('12345-1234567-1', UserRole.driver),
        isNull,
      );
      expect(
        SignUpValidators.cnic('12345', UserRole.driver),
        isNotNull,
      );
      expect(SignUpValidators.cnic('12345', UserRole.admin), isNull);
    });

    test('password strength and confirmation', () {
      expect(SignUpValidators.password('short'), isNotNull);
      expect(SignUpValidators.password('longenough'), isNull);
      expect(SignUpValidators.confirmPassword('abc', 'abc'), isNull);
      expect(SignUpValidators.confirmPassword('abc', 'xyz'), isNotNull);
    });
  });

  group('SignUpRequest', () {
    test('exposes role-driven requirements', () {
      const student = SignUpRequest(
        email: '23cs092@students.muet.edu.pk',
        password: 'password1',
        fullName: 'Student',
        role: UserRole.student,
      );
      const driver = SignUpRequest(
        email: 'driver@muet.edu.pk',
        password: 'password1',
        fullName: 'Driver',
        role: UserRole.driver,
        inviteCode: 'MUET-DRIVER-2026',
        cnic: '12345-1234567-1',
      );
      const admin = SignUpRequest(
        email: 'admin@muet.edu.pk',
        password: 'password1',
        fullName: 'Admin',
        role: UserRole.admin,
        inviteCode: 'MUET-ADMIN-2026',
      );

      expect(student.requiresInviteCode, isFalse);
      expect(student.requiresCnic, isFalse);
      expect(student.isStudent, isTrue);

      expect(driver.requiresInviteCode, isTrue);
      expect(driver.requiresCnic, isTrue);

      expect(admin.requiresInviteCode, isTrue);
      expect(admin.requiresCnic, isFalse);
    });
  });

  group('SignUpPage', () {
    Future<void> pumpSignUp(WidgetTester tester, AuthRepository repository) async {
      tester.view.physicalSize = const Size(1100, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: SignUpPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('defaults to student and hides provisioning fields', (tester) async {
      await pumpSignUp(tester, _FakeAuthRepository());

      expect(find.byKey(const Key('signup-role')), findsOneWidget);
      expect(find.byKey(const Key('signup-invite-code')), findsNothing);
      expect(find.text('CNIC (12345-1234567-1)'), findsNothing);
      expect(find.byKey(const Key('signup-submit')), findsOneWidget);
    });

    testWidgets('shows provisioning code and CNIC for the driver role', (tester) async {
      await pumpSignUp(tester, _FakeAuthRepository());

      await tester.tap(find.byKey(const Key('signup-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Driver'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('signup-invite-code')), findsOneWidget);
      expect(find.text('CNIC (12345-1234567-1)'), findsOneWidget);
    });

    testWidgets('rejects a non-student email for the student role', (tester) async {
      final repository = _FakeAuthRepository();
      await pumpSignUp(tester, repository);

      await tester.enterText(find.byKey(const Key('signup-fullname')), 'Ali Khan');
      await tester.enterText(find.byKey(const Key('signup-email')), 'ali@muet.edu.pk');
      await tester.enterText(find.byKey(const Key('signup-password')), 'password123');
      await tester.enterText(
        find.byKey(const Key('signup-confirm-password')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('Student accounts must use a @students.muet.edu.pk address.'),
        findsOneWidget,
      );
      expect(repository.lastRequest, isNull);
    });

    testWidgets('signs up a driver with the provisioning code', (tester) async {
      final repository = _FakeAuthRepository();
      await pumpSignUp(tester, repository);

      await tester.tap(find.byKey(const Key('signup-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Driver'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('signup-fullname')), 'Ali Khan');
      await tester.enterText(
        find.byKey(const Key('signup-email')),
        'ali.driver@muet.edu.pk',
      );
      await tester.enterText(find.byKey(const Key('signup-cnic')), '12345-1234567-1');
      await tester.enterText(
        find.byKey(const Key('signup-password')),
        'password123',
      );
      await tester.enterText(
        find.byKey(const Key('signup-confirm-password')),
        'password123',
      );
      await tester.enterText(find.byKey(const Key('signup-invite-code')), 'MUET-DRIVER-2026');
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();

      expect(repository.lastRequest, isNotNull);
      expect(repository.lastRequest!.role, UserRole.driver);
      expect(repository.lastRequest!.inviteCode, 'MUET-DRIVER-2026');
      expect(repository.lastRequest!.cnic, '12345-1234567-1');
      expect(find.text('Confirm your email'), findsOneWidget);
    });

    testWidgets('surfaces a rejected provisioning code', (tester) async {
      final repository = _FakeAuthRepository(codeValid: false);
      await pumpSignUp(tester, repository);

      await tester.tap(find.byKey(const Key('signup-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Administrator'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('signup-fullname')),
        'Transport Admin',
      );
      await tester.enterText(find.byKey(const Key('signup-email')), 'admin@muet.edu.pk');
      await tester.enterText(
        find.byKey(const Key('signup-password')),
        'password123',
      );
      await tester.enterText(
        find.byKey(const Key('signup-confirm-password')),
        'password123',
      );
      await tester.enterText(find.byKey(const Key('signup-invite-code')), 'WRONG-CODE');
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('not valid for the Administrator role'), findsOneWidget);
      expect(repository.lastRequest, isNull);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    SignUpResult? signUpResult,
    this.codeValid = true,
  }) : _signUpResult = signUpResult ?? const SignUpResult.emailConfirmationRequired();

  final SignUpResult _signUpResult;
  final bool codeValid;

  SignUpRequest? lastRequest;

  @override
  Stream<void> get sessionChanges => const Stream<void>.empty();

  @override
  Future<AuthenticatedUser?> restoreSession() async => null;

  @override
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError('signIn is not used by these tests');
  }

  @override
  Future<SignUpResult> signUp(SignUpRequest request) async {
    lastRequest = request;
    return _signUpResult;
  }

  @override
  Future<bool> validateProvisioningCode({
    required String code,
    required UserRole role,
  }) async =>
      codeValid;

  @override
  Future<void> signOut() async {}
}
