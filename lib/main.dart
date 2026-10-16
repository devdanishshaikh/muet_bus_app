import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/config/environment.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

const String _notificationChannel = 'com.muet.muet_smart_bus_tracking_system/notifications';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Environment.isConfigured) {
    await Supabase.initialize(
      url: Environment.supabaseUrl,
      publishableKey: Environment.supabasePublishableKey,
    );
  }

  // Set up MethodChannel for notification tap handling
  const MethodChannel(_notificationChannel).setMethodCallHandler((call) async {
    if (call.method == 'notificationTap') {
      final payload = call.arguments as String?;
      debugPrint('Notification tap received with payload: $payload');
      // Handle navigation to live tracking page
      // The navigation will be handled when the app is fully built
    }
    return null;
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: AppConfig.appName,
        theme: AppTheme.light,
        initialRoute: AppConstants.homeRoute,
        routes: AppRouter.routes,
      ),
    );
  }
}