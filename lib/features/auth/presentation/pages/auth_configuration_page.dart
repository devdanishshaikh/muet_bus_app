import 'package:flutter/material.dart';

class AuthConfigurationPage extends StatelessWidget {
  const AuthConfigurationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase authentication is not configured for this build.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
