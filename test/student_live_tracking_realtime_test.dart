import 'package:flutter_test/flutter_test.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_live_tracking.dart';
import 'package:muet_smart_bus_tracking_system/features/student/domain/student_tracking_selection.dart';

void main() {
  group('StudentLiveTracking model - copyWith', () {
    test('copyWith updates location', () {
      final original = StudentLiveTracking(
        tripId: 'trip-1',
        busId: 'bus-1',
        routeId: 'route-1',
        busNumber: 'B-01',
        busName: 'Shuttle',
        busStatus: 'active',
        routeName: 'Main Route',
        tripStatus: 'active',
        tripStartedAt: DateTime(2024, 1, 1),
        location: null,
      );

      final newLocation = StudentBusLocation(
        latitude: 24.8607,
        longitude: 67.0011,
        recordedAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final updated = original.copyWith(location: newLocation);

      expect(updated.location, newLocation);
      expect(updated.tripId, original.tripId);
    });

    test('copyWith updates realtimeStatus', () {
      final original = StudentLiveTracking(
        tripId: 'trip-1',
        busId: 'bus-1',
        routeId: 'route-1',
        busNumber: 'B-01',
        busName: 'Shuttle',
        busStatus: 'active',
        routeName: 'Main Route',
        tripStatus: 'active',
        tripStartedAt: DateTime(2024, 1, 1),
        realtimeStatus: StudentRealtimeStatus.connecting,
      );

      final updated = original.copyWith(realtimeStatus: StudentRealtimeStatus.connected);

      expect(updated.realtimeStatus, StudentRealtimeStatus.connected);
      expect(updated.realtimeError, isNull);
    });

    test('copyWith clears realtimeError when clearRealtimeError is true', () {
      final original = StudentLiveTracking(
        tripId: 'trip-1',
        busId: 'bus-1',
        routeId: 'route-1',
        busNumber: 'B-01',
        busName: 'Shuttle',
        busStatus: 'active',
        routeName: 'Main Route',
        tripStatus: 'active',
        tripStartedAt: DateTime(2024, 1, 1),
        realtimeError: 'Connection lost',
      );

      final updated = original.copyWith(clearRealtimeError: true);

      expect(updated.realtimeError, isNull);
    });

    test('copyWith updates realtimeError', () {
      final original = StudentLiveTracking(
        tripId: 'trip-1',
        busId: 'bus-1',
        routeId: 'route-1',
        busNumber: 'B-01',
        busName: 'Shuttle',
        busStatus: 'active',
        routeName: 'Main Route',
        tripStatus: 'active',
        tripStartedAt: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(realtimeError: 'New error');

      expect(updated.realtimeError, 'New error');
    });

    test('copyWith preserves other fields when only updating one', () {
      final original = StudentLiveTracking(
        tripId: 'trip-1',
        busId: 'bus-1',
        routeId: 'route-1',
        busNumber: 'B-01',
        busName: 'Shuttle',
        busStatus: 'active',
        routeName: 'Main Route',
        tripStatus: 'active',
        tripStartedAt: DateTime(2024, 1, 1),
        realtimeStatus: StudentRealtimeStatus.connecting,
        realtimeError: 'Old error',
      );

      final updated = original.copyWith(
        realtimeStatus: StudentRealtimeStatus.connected,
        clearRealtimeError: true,
      );

      expect(updated.realtimeStatus, StudentRealtimeStatus.connected);
      expect(updated.realtimeError, isNull);
      expect(updated.busNumber, 'B-01');
      expect(updated.routeName, 'Main Route');
    });
  });

  group('StudentBusLocation', () {
    test('isValid returns true for valid coordinates', () {
      final location = StudentBusLocation(
        latitude: 24.8607,
        longitude: 67.0011,
        recordedAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      expect(location.isValid, isTrue);
    });

    test('isValid returns false for invalid latitude', () {
      final location = StudentBusLocation(
        latitude: 91.0,
        longitude: 67.0011,
        recordedAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      expect(location.isValid, isFalse);
    });

    test('isValid returns false for invalid longitude', () {
      final location = StudentBusLocation(
        latitude: 24.8607,
        longitude: 181.0,
        recordedAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      expect(location.isValid, isFalse);
    });

    test('isValid returns false for NaN latitude', () {
      final location = StudentBusLocation(
        latitude: double.nan,
        longitude: 67.0011,
        recordedAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      expect(location.isValid, isFalse);
    });

    test('isValid returns false for NaN longitude', () {
      final location = StudentBusLocation(
        latitude: 24.8607,
        longitude: double.nan,
        recordedAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      expect(location.isValid, isFalse);
    });

    test('isValid returns false for infinity coordinates', () {
      final location = StudentBusLocation(
        latitude: double.infinity,
        longitude: 67.0011,
        recordedAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      expect(location.isValid, isFalse);
    });
  });

  group('StudentRealtimeStatus', () {
    test('has all expected values', () {
      expect(StudentRealtimeStatus.values, [
        StudentRealtimeStatus.connecting,
        StudentRealtimeStatus.connected,
        StudentRealtimeStatus.reconnecting,
        StudentRealtimeStatus.disconnected,
        StudentRealtimeStatus.error,
      ]);
    });
  });

  group('StudentTrackingSelection', () {
    test('equality works correctly', () {
      const sel1 = StudentTrackingSelection(routeId: 'route-1', busId: 'bus-1');
      const sel2 = StudentTrackingSelection(routeId: 'route-1', busId: 'bus-1');
      const sel3 = StudentTrackingSelection(routeId: 'route-2', busId: 'bus-1');

      expect(sel1 == sel2, isTrue);
      expect(sel1 == sel3, isFalse);
    });

    test('hashCode is consistent with equality', () {
      const sel1 = StudentTrackingSelection(routeId: 'route-1', busId: 'bus-1');
      const sel2 = StudentTrackingSelection(routeId: 'route-1', busId: 'bus-1');

      expect(sel1.hashCode, sel2.hashCode);
    });

    test('works with null routeId and busId', () {
      const sel1 = StudentTrackingSelection(routeId: null, busId: null);
      const sel2 = StudentTrackingSelection(routeId: null, busId: null);

      expect(sel1 == sel2, isTrue);
      expect(sel1.routeId, isNull);
      expect(sel1.busId, isNull);
    });
  });
}