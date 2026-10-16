import 'student_live_tracking.dart';

abstract interface class StudentLiveTrackingRepository {
  /// Loads all active trips with the latest readable location per trip.
  ///
  /// This is intentionally a one-shot read. A Supabase Realtime stream can be
  /// added beside it later without changing student UI ownership.
  Future<List<StudentLiveTracking>> loadActiveBuses();

  Future<StudentLiveTracking?> load({String? routeId, String? busId});

  /// Stream of active bus snapshots for Supabase Realtime integration.
  ///
  /// This is a placeholder for future Realtime implementation.
  /// Currently returns an empty stream; will be connected to Supabase
  /// Realtime channels in a later step.
  Stream<List<StudentLiveTracking>> watchActiveBuses() async* {
    yield [];
  }
}
