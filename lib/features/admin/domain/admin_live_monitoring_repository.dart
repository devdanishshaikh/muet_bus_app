import 'admin_live_monitoring_data.dart';

abstract interface class AdminLiveMonitoringRepository {
  /// Load active trips and their latest bus locations (one-shot).
  Future<List<MonitoredBus>> loadActiveTrips();

  /// Stream active trips with realtime location updates.
  Stream<AdminLiveMonitoringSnapshot> watchActiveTrips();
}
