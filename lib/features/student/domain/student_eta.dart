import 'dart:math' as math;

import 'student_live_tracking.dart';
import 'student_route.dart';

class StudentEta {
  const StudentEta({required this.duration, required this.distanceMeters});

  final Duration duration;
  final double distanceMeters;

  int get roundedMinutes => math.max(1, duration.inMinutes);
}

abstract final class StudentEtaCalculator {
  static StudentEta? calculate({
    required StudentBusLocation? location,
    required StudentRouteStop stop,
  }) {
    final distanceMeters = distanceToStop(location: location, stop: stop);
    final speed = location?.speedMetersPerSecond;
    if (distanceMeters == null ||
        speed == null ||
        !speed.isFinite ||
        speed <= 0) {
      return null;
    }

    final seconds = distanceMeters / speed;
    return StudentEta(
      duration: Duration(seconds: seconds.ceil()),
      distanceMeters: distanceMeters,
    );
  }

  static double? distanceToStop({
    required StudentBusLocation? location,
    required StudentRouteStop stop,
  }) {
    final stopLatitude = stop.latitude;
    final stopLongitude = stop.longitude;
    if (location == null ||
        !location.isValid ||
        stopLatitude == null ||
        stopLongitude == null ||
        !_validCoordinate(stopLatitude, stopLongitude)) {
      return null;
    }

    return _haversineDistance(
      location.latitude,
      location.longitude,
      stopLatitude,
      stopLongitude,
    );
  }

  static bool _validCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  static double _haversineDistance(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    const earthRadiusMeters = 6371000.0;
    final latitudeDelta = _radians(secondLatitude - firstLatitude);
    final longitudeDelta = _radians(secondLongitude - firstLongitude);
    final firstLatitudeRadians = _radians(firstLatitude);
    final secondLatitudeRadians = _radians(secondLatitude);
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(firstLatitudeRadians) *
            math.cos(secondLatitudeRadians) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    final centralAngle = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * centralAngle;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
