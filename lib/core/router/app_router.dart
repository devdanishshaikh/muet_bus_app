import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../../features/auth/presentation/auth_gate.dart';

abstract final class AppRouter {
  static final routes = <String, WidgetBuilder>{
    AppConstants.homeRoute: (_) => const AuthGate(),
  };
}
