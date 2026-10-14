import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/student_arrival_notification_monitor.dart';
import '../data/student_notification_service.dart';
import 'student_stop_selection_providers.dart';

final studentNotificationServiceProvider = Provider<StudentNotificationService>(
  (ref) => StudentNotificationService(),
);

final studentArrivalNotificationMonitorProvider =
    Provider<StudentArrivalNotificationMonitor>((ref) {
      return StudentArrivalNotificationMonitor(
        notificationService: ref.watch(studentNotificationServiceProvider),
        selectionRepository: ref.watch(studentStopSelectionRepositoryProvider),
      );
    });
