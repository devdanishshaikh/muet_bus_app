import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/student_stop_selection.dart';
import '../domain/student_stop_selection_repository.dart';

class SupabaseStudentStopSelectionRepository
    implements StudentStopSelectionRepository {
  const SupabaseStudentStopSelectionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<StudentStopSelection>> loadForStudent(String profileId) async {
    final student = await _student(profileId);
    if (student == null) {
      return const [];
    }

    final rows = await _client
        .from('student_alerts')
        .select('''
          id, stop_id, bus_id, radius_meters, enabled, triggered_at,
          buses!bus_id (bus_number, bus_name),
          stops!stop_id (name, route_id),
          routes!stops_route_id (name)
        ''')
        .eq('student_id', student['id'] as String)
        .order('created_at', ascending: false);

    return rows.map(_parse).toList();
  }

  @override
  Future<StudentStopSelection> save({
    required String profileId,
    required String stopId,
    required String busId,
    required double radiusMeters,
  }) async {
    final student = await _student(profileId);
    if (student == null) {
      throw const FormatException('Student profile is not configured.');
    }

    final studentRecordId = student['id'] as String;
    final existing = await _client
        .from('student_alerts')
        .select('id')
        .eq('student_id', studentRecordId)
        .eq('stop_id', stopId)
        .eq('enabled', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final row = existing == null
        ? await _client
              .from('student_alerts')
              .insert({
                'student_id': studentRecordId,
                'bus_id': busId,
                'stop_id': stopId,
                'radius_meters': radiusMeters,
                'enabled': true,
              })
              .select('id, stop_id, bus_id, radius_meters, enabled, triggered_at')
              .single()
        : await _client
              .from('student_alerts')
              .update({
                'bus_id': busId,
                'radius_meters': radiusMeters,
                'enabled': true,
                'triggered_at': null,
              })
              .eq('id', existing['id'] as String)
              .eq('student_id', studentRecordId)
              .select('id, stop_id, bus_id, radius_meters, enabled, triggered_at')
              .single();

    // Fetch the full alert with related data
    return loadForStudent(profileId).then((alerts) {
      final alert = alerts.firstWhere((a) => a.id == row['id'] as String);
      return alert;
    });
  }

  @override
  Future<void> remove({
    required String profileId,
    required String selectionId,
  }) async {
    final student = await _student(profileId);
    if (student == null) {
      return;
    }

    await _client
        .from('student_alerts')
        .delete()
        .eq('id', selectionId)
        .eq('student_id', student['id'] as String);
  }

  @override
  Future<void> markTriggered({
    required String profileId,
    required String selectionId,
  }) async {
    final student = await _student(profileId);
    if (student == null) {
      return;
    }

    await _client
        .from('student_alerts')
        .update({'triggered_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', selectionId)
        .eq('student_id', student['id'] as String);
  }

  @override
  Future<void> setEnabled({
    required String profileId,
    required String selectionId,
    required bool enabled,
  }) async {
    final student = await _student(profileId);
    if (student == null) {
      return;
    }

    await _client
        .from('student_alerts')
        .update({'enabled': enabled})
        .eq('id', selectionId)
        .eq('student_id', student['id'] as String);
  }

  Future<Map<String, dynamic>?> _student(String profileId) {
    return _client
        .from('students')
        .select('id')
        .eq('profile_id', profileId)
        .maybeSingle();
  }

  StudentStopSelection _parse(Map<String, dynamic> row) {
    final bus = row['buses'] as Map<String, dynamic>?;
    final stop = row['stops'] as Map<String, dynamic>?;
    final route = stop != null ? stop['routes'] as Map<String, dynamic>? : null;

    return StudentStopSelection(
      id: row['id'] as String,
      stopId: row['stop_id'] as String,
      busId: row['bus_id'] as String,
      radiusMeters: double.parse(row['radius_meters'].toString()),
      enabled: row['enabled'] as bool? ?? false,
      triggeredAt: row['triggered_at'] == null
          ? null
          : DateTime.tryParse(row['triggered_at'].toString()),
      busNumber: bus?['bus_number'] as String?,
      busName: bus?['bus_name'] as String?,
      stopName: stop?['name'] as String?,
      routeName: route?['name'] as String?,
    );
  }
}