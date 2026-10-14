import 'student_stop_selection.dart';

abstract interface class StudentStopSelectionRepository {
  Future<List<StudentStopSelection>> loadForStudent(String profileId);

  Future<StudentStopSelection> save({
    required String profileId,
    required String stopId,
    required String busId,
    required double radiusMeters,
  });

  Future<void> remove({required String profileId, required String selectionId});

  Future<void> markTriggered({
    required String profileId,
    required String selectionId,
  });

  Future<void> setEnabled({
    required String profileId,
    required String selectionId,
    required bool enabled,
  });
}
