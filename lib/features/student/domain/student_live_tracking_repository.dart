import 'student_live_tracking.dart';

abstract interface class StudentLiveTrackingRepository {
  /// Loads all active trips with the latest readable location per trip.
  ///
  /// This is intentionally a one-shot read. A Supabase Realtime stream can be
  /// added beside it later without changing student UI ownership.
  Future<List<StudentLiveTracking>> loadActiveBuses();

  Future<StudentLiveTracking?> load({String? routeId, String? busId});
}
