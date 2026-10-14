import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_eta.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_live_tracking.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_route.dart';

void main() {
  test(
    'calculates an approximate ETA from location speed and stop coordinates',
    () {
      final eta = StudentEtaCalculator.calculate(
        location: StudentBusLocation(
          latitude: 24.8607,
          longitude: 67.0011,
          recordedAt: DateTime.now(),
          speedMetersPerSecond: 10,
        ),
        stop: const StudentRouteStop(
          id: 'stop-id',
          name: 'Stop',
          stopOrder: 1,
          latitude: 24.8617,
          longitude: 67.0011,
        ),
      );

      expect(eta, isNotNull);
      expect(eta!.distanceMeters, greaterThan(0));
      expect(eta.duration.inSeconds, greaterThan(0));
    },
  );

  test('returns unavailable when speed or coordinates are missing', () {
    final eta = StudentEtaCalculator.calculate(
      location: StudentBusLocation(
        latitude: 24.8607,
        longitude: 67.0011,
        recordedAt: DateTime.now(),
      ),
      stop: const StudentRouteStop(id: 'stop-id', name: 'Stop', stopOrder: 1),
    );

    expect(eta, isNull);
  });
}
