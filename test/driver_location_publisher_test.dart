import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:muet_smart_bus_tracking_system/features/driver/data/supabase_driver_location_publisher.dart';
import 'package:muet_smart_bus_tracking_system/features/driver/domain/driver_location_publisher.dart';
import 'package:muet_smart_bus_tracking_system/features/driver/domain/driver_location_state.dart';
import 'package:muet_smart_bus_tracking_system/features/driver/presentation/driver_location_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'driver_location_publisher_test.mocks.dart';

@GenerateMocks([SupabaseClient, DriverLocationPublisher])
void main() {
  group('SupabaseDriverLocationPublisher', () {
    late MockSupabaseClient mockClient;
    late SupabaseDriverLocationPublisher publisher;

    setUp(() {
      mockClient = MockSupabaseClient();
      publisher = SupabaseDriverLocationPublisher(mockClient);
    });

    tearDown(() async {
      await publisher.stop();
    });

    test('stop() emits stopped state', () async {
      final states = <DriverLocationState>[];
      final subscription = publisher.states.listen(states.add);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await publisher.stop();

      await Future<void>.delayed(const Duration(milliseconds: 200));
      await subscription.cancel();

      expect(states.any((s) => s.status == DriverLocationStatus.stopped), isTrue);
    });

    test('pause() and resume() do not crash', () async {
      final states = <DriverLocationState>[];
      final subscription = publisher.states.listen(states.add);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await publisher.pause();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      await publisher.resume();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      await subscription.cancel();

      // Just verify no crash occurs
      expect(true, isTrue);
    });
  });

  group('DriverLocationController', () {
    late ProviderContainer container;
    late MockDriverLocationPublisher mockPublisher;

    setUp(() {
      mockPublisher = MockDriverLocationPublisher();
      // Provide a stream that emits idle and allows state changes
      final stateController = StreamController<DriverLocationState>.broadcast();
      stateController.add(const DriverLocationState.idle());

      when(mockPublisher.states).thenAnswer(
        (_) => stateController.stream,
      );
      when(mockPublisher.start(tripId: anyNamed('tripId'))).thenAnswer((_) async {});
      when(mockPublisher.stop()).thenAnswer((_) async {});
      when(mockPublisher.pause()).thenAnswer((_) async {});
      when(mockPublisher.resume()).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          driverLocationPublisherProvider.overrideWithValue(mockPublisher),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('controller starts in idle state', () {
      final state = container.read(driverLocationControllerProvider);
      expect(state, const DriverLocationState.idle());
    });

    test('start() calls publisher.start() with tripId', () async {
      await container.read(driverLocationControllerProvider.notifier).start('trip-123');
      verify(mockPublisher.start(tripId: 'trip-123')).called(1);
    });

    test('stop() calls publisher.stop()', () async {
      await container.read(driverLocationControllerProvider.notifier).stop();
      verify(mockPublisher.stop()).called(1);
    });

    test('pause() calls publisher.pause()', () async {
      await container.read(driverLocationControllerProvider.notifier).pause();
      verify(mockPublisher.pause()).called(1);
    });

    test('resume() calls publisher.resume()', () async {
      await container.read(driverLocationControllerProvider.notifier).resume();
      verify(mockPublisher.resume()).called(1);
    });

    test('controller calls start() for different trips', () async {
      await container.read(driverLocationControllerProvider.notifier).start('trip-123');
      await container.read(driverLocationControllerProvider.notifier).start('trip-456');
      verify(mockPublisher.start(tripId: 'trip-123')).called(1);
      verify(mockPublisher.start(tripId: 'trip-456')).called(1);
    });

    test('controller disposes on stop', () async {
      await container.read(driverLocationControllerProvider.notifier).start('trip-123');
      await container.read(driverLocationControllerProvider.notifier).stop();

      verify(mockPublisher.stop()).called(1);
    });
  });

  group('DriverLocationState', () {
    test('idle state has correct defaults', () {
      const state = DriverLocationState.idle();
      expect(state.status, DriverLocationStatus.idle);
      expect(state.message, isNull);
      expect(state.lastRecordedAt, isNull);
    });

    test('copyWith updates status', () {
      const original = DriverLocationState.idle();
      final updated = original.copyWith(status: DriverLocationStatus.tracking);

      expect(updated.status, DriverLocationStatus.tracking);
      expect(updated.message, isNull);
      expect(updated.lastRecordedAt, isNull);
    });

    test('copyWith updates message', () {
      const original = DriverLocationState.idle();
      final updated = original.copyWith(message: 'Test message');

      expect(updated.message, 'Test message');
    });

    test('copyWith clears message when clearMessage is true', () {
      const original = DriverLocationState(
        status: DriverLocationStatus.idle,
        message: 'Test',
      );
      final updated = original.copyWith(clearMessage: true);

      expect(updated.message, isNull);
    });

    test('copyWith updates lastRecordedAt', () {
      const original = DriverLocationState.idle();
      final now = DateTime.now();
      final updated = original.copyWith(lastRecordedAt: now);

      expect(updated.lastRecordedAt, now);
    });
  });
}