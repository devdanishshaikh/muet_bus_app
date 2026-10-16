import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_failure.dart';
import '../../domain/sign_up_request.dart';
import '../../domain/sign_up_validators.dart';
import '../../domain/user_role.dart';
import '../auth_providers.dart';

/// Self-service registration for students, drivers and administrators.
///
/// Drivers and administrators must supply a provisioning code issued by the
/// transport office; students register with a MUET student email address.
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  static const List<UserRole> _roles = [
    UserRole.student,
    UserRole.driver,
    UserRole.admin,
  ];

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _cnicController = TextEditingController();
  final _phoneController = TextEditingController();

  UserRole _role = UserRole.student;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _roleLabel(UserRole role) {
    return switch (role) {
      UserRole.student => 'Student',
      UserRole.driver => 'Driver',
      UserRole.admin => 'Administrator',
      UserRole.unknown => 'Unknown',
    };
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final phone = _phoneController.text.trim();
    final inviteCode = _inviteCodeController.text.trim();
    final request = SignUpRequest(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      role: _role,
      inviteCode: _role == UserRole.student ? null : inviteCode,
      cnic: _role == UserRole.driver ? _cnicController.text.trim() : null,
      phone: phone.isEmpty ? null : phone,
    );

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      if (request.requiresInviteCode) {
        final isCodeValid = await _verifyProvisioningCode(inviteCode);
        if (!isCodeValid) {
          if (!mounted) return;
          setState(() {
            _submitting = false;
            _errorMessage =
                'That provisioning code is not valid for the ${_roleLabel(_role)} role.';
          });
          return;
        }
      }

      final result = await ref
          .read(authControllerProvider.notifier)
          .signUp(request);

      if (!mounted) return;
      setState(() => _submitting = false);

      if (result.requiresEmailConfirmation) {
        await _showConfirmationDialog();
      } else if (mounted) {
        // Return to the auth gate so it can route by the new role.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = error is AuthFailure
            ? error.message
            : 'Unable to create the account. Please try again.';
      });
    }
  }

  Future<bool> _verifyProvisioningCode(String code) async {
    try {
      return await ref
          .read(authControllerProvider.notifier)
          .validateProvisioningCode(code: code, role: _role);
    } catch (_) {
      // If the check is unavailable, let the database decide during sign-up.
      return true;
    }
  }

  Future<void> _showConfirmationDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm your email'),
        content: Text(
          'We created your account. Open the confirmation link sent to '
          '${_emailController.text.trim()}, then sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showInviteCode = _role != UserRole.student;
    final showCnic = _role == UserRole.driver;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Join MUET Smart Bus Tracking',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _role == UserRole.student
                          ? 'Students register with a MUET student email address.'
                          : 'Drivers and administrators need a provisioning code from the transport office.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<UserRole>(
                      key: const Key('signup-role'),
                      initialValue: _role,
                      decoration: _decoration('I am signing up as', Icons.badge_outlined),
                      items: [
                        for (final role in _roles)
                          DropdownMenuItem<UserRole>(
                            value: role,
                            child: Text(_roleLabel(role)),
                          ),
                      ],
                      onChanged: (role) {
                        setState(() {
                          _role = role ?? _role;
                          _errorMessage = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('signup-fullname'),
                      controller: _fullNameController,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        'Full name',
                        Icons.person_outline,
                      ),
                      validator: SignUpValidators.fullName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('signup-email'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: _decoration(
                        _role == UserRole.student
                            ? 'MUET student email'
                            : 'Email',
                        Icons.email_outlined,
                      ),
                      validator: (value) => SignUpValidators.email(value, _role),
                    ),
                    if (showCnic) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('signup-cnic'),
                        controller: _cnicController,
                        textInputAction: TextInputAction.next,
                        decoration: _decoration(
                          'CNIC (12345-1234567-1)',
                          Icons.credit_card_outlined,
                        ),
                        validator: (value) =>
                            SignUpValidators.cnic(value, _role),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        'Phone (optional)',
                        Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('signup-password'),
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: _decoration(
                        'Password',
                        Icons.lock_outline,
                      ),
                      validator: SignUpValidators.password,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('signup-confirm-password'),
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: _decoration(
                        'Confirm password',
                        Icons.lock_reset_outlined,
                      ),
                      validator: (value) => SignUpValidators.confirmPassword(
                        value,
                        _passwordController.text,
                      ),
                    ),
                    if (showInviteCode) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('signup-invite-code'),
                        controller: _inviteCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _decoration(
                          'Provisioning code',
                          Icons.vpn_key_outlined,
                        ),
                        validator: (value) =>
                            SignUpValidators.inviteCode(value, _role),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('signup-submit'),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create account'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('I already have an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
