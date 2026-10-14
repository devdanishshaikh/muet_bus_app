import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/driver_location_publisher.dart';
import '../domain/driver_location_state.dart';

class SupabaseDriverLocationPublisher implements DriverLocationPublisher {
  SupabaseDriverLocationPublisher(this._client);

  final SupabaseClient _client;
  final StreamController<DriverLocationState> _states =
      StreamController<DriverLocationState>.broadcast();

  StreamSubscription<Position>? _positionSubscription;
  String? _tripId;
  DateTime? _lastPublishedAt;
  DriverLocationState _state = const DriverLocationState.idle();

  @override
  Stream<DriverLocationState> get states => _states.stream;

  @override
  Future<void> start({required String tripId}) async {
    await stop();
    _tripId = tripId;
    _setState(
      const DriverLocationState(
        status: DriverLocationStatus.requestingPermission,
      ),
    );

    if (!await Geolocator.isLocationServiceEnabled()) {
      _setState(
        const DriverLocationState(
          status: DriverLocationStatus.serviceDisabled,
          message: 'Enable location services to publish your bus location.',
        ),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _setState(
        const DriverLocationState(
          status: DriverLocationStatus.permissionDenied,
          message: 'Location permission is required for an active trip.',
        ),
      );
      return;
    }

    try {
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
            _publishPosition,
            onError: (Object error) {
              _setState(
                DriverLocationState(
                  status: DriverLocationStatus.unavailable,
                  message: 'Location updates are unavailable.',
                  lastRecordedAt: _state.lastRecordedAt,
                ),
              );
            },
          );
      _setState(
        const DriverLocationState(status: DriverLocationStatus.tracking),
      );
    } catch (error) {
      _setState(
        DriverLocationState(
          status: DriverLocationStatus.error,
          message: 'Could not start location tracking.',
          lastRecordedAt: _state.lastRecordedAt,
        ),
      );
    }
  }

  @override
  Future<void> pause() async {
    _positionSubscription?.pause();
    if (_tripId != null) {
      _setState(_state.copyWith(status: DriverLocationStatus.paused));
    }
  }

  @override
  Future<void> resume() async {
    if (_tripId == null) {
      return;
    }
    if (_positionSubscription != null) {
      _positionSubscription!.resume();
      _setState(_state.copyWith(status: DriverLocationStatus.tracking));
      return;
    }
    await start(tripId: _tripId!);
  }

  @override
  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _tripId = null;
    _lastPublishedAt = null;
    _setState(const DriverLocationState(status: DriverLocationStatus.stopped));
  }

  Future<void> _publishPosition(Position position) async {
    final tripId = _tripId;
    if (tripId == null) {
      return;
    }

    final now = DateTime.now().toUtc();
    final lastPublishedAt = _lastPublishedAt;
    if (lastPublishedAt != null &&
        now.difference(lastPublishedAt).inSeconds < 10) {
      return;
    }

    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180) {
      _setState(
        DriverLocationState(
          status: DriverLocationStatus.unavailable,
          message: 'The device returned an invalid location.',
          lastRecordedAt: _state.lastRecordedAt,
        ),
      );
      return;
    }

    try {
      await _client.from('bus_locations').insert({
        'trip_id': tripId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed.isFinite && position.speed >= 0
            ? position.speed
            : null,
        'heading':
            position.heading.isFinite &&
                position.heading >= 0 &&
                position.heading < 360
            ? position.heading
            : null,
        'recorded_at': now.toIso8601String(),
      });
      _lastPublishedAt = now;
      _setState(
        DriverLocationState(
          status: DriverLocationStatus.tracking,
          lastRecordedAt: now,
        ),
      );
    } catch (error) {
      _setState(
        DriverLocationState(
          status: DriverLocationStatus.error,
          message: 'Location could not be published.',
          lastRecordedAt: _state.lastRecordedAt,
        ),
      );
    }
  }

  void _setState(DriverLocationState state) {
    _state = state;
    if (!_states.isClosed) {
      _states.add(state);
    }
  }
}
