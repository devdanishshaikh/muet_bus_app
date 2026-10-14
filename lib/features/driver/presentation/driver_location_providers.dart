import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_driver_location_publisher.dart';
import '../domain/driver_location_publisher.dart';
import '../domain/driver_location_state.dart';

final driverLocationPublisherProvider = Provider<DriverLocationPublisher>(
  (ref) => SupabaseDriverLocationPublisher(Supabase.instance.client),
);

final driverLocationControllerProvider =
    NotifierProvider.autoDispose<DriverLocationController, DriverLocationState>(
      DriverLocationController.new,
    );

class DriverLocationController
    extends AutoDisposeNotifier<DriverLocationState> {
  late final DriverLocationPublisher _publisher;
  StreamSubscription<DriverLocationState>? _subscription;
  String? _activeTripId;

  @override
  DriverLocationState build() {
    _publisher = ref.watch(driverLocationPublisherProvider);
    _subscription = _publisher.states.listen((next) => state = next);
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      unawaited(_publisher.stop());
    });
    return const DriverLocationState.idle();
  }

  Future<void> start(String tripId) async {
    if (_activeTripId == tripId &&
        state.status == DriverLocationStatus.tracking) {
      return;
    }
    _activeTripId = tripId;
    await _publisher.start(tripId: tripId);
  }

  Future<void> pause() => _publisher.pause();

  Future<void> resume() => _publisher.resume();

  Future<void> stop() async {
    _activeTripId = null;
    await _publisher.stop();
  }
}
