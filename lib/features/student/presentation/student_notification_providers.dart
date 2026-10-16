import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/student_alert_monitor.dart';
import '../data/student_arrival_notification_monitor.dart';
import '../data/student_notification_service.dart';
import 'student_stop_selection_providers.dart';

final studentNotificationServiceProvider = Provider<StudentNotificationService>((ref) {
  return StudentNotificationService(
    onNotificationTap: (payload) {
      _handleNotificationTap(payload);
    },
  );
});

void _handleNotificationTap(String? payload) {
  debugPrint('Notification tapped with payload: $payload');
  // The navigation will be handled by the app's router when the MethodChannel
  // receives the notificationTap event from native code.
  debugPrint('Notification tap handled for payload: $payload');
}

// Provider to handle notification tap navigation
final notificationTapHandlerProvider = Provider<void Function(String)>((ref) {
  return (payload) {
    _handleNotificationNavigation(payload);
  };
});

void _handleNotificationNavigation(String payload) {
  debugPrint('Navigation payload: $payload');
  // The actual navigation is handled by the MethodChannel in MainActivity/AppDelegate
  // which calls back into Flutter via the MethodChannel
}

final studentArrivalNotificationMonitorProvider =
    Provider<StudentArrivalNotificationMonitor>((ref) {
  return StudentArrivalNotificationMonitor(
    notificationService: ref.watch(studentNotificationServiceProvider),
    selectionRepository: ref.watch(studentStopSelectionRepositoryProvider),
  );
});

final studentAlertMonitorProvider = Provider<StudentAlertMonitor>((ref) {
  return StudentAlertMonitor(
    notificationService: ref.watch(studentNotificationServiceProvider),
    selectionRepository: ref.watch(studentStopSelectionRepositoryProvider),
    client: Supabase.instance.client,
  );
});