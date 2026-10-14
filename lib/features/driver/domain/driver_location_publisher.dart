import 'driver_location_state.dart';

abstract interface class DriverLocationPublisher {
  Stream<DriverLocationState> get states;

  Future<void> start({required String tripId});

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();
}
