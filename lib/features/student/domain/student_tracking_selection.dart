class StudentTrackingSelection {
  const StudentTrackingSelection({this.routeId, this.busId});

  final String? routeId;
  final String? busId;

  @override
  bool operator ==(Object other) {
    return other is StudentTrackingSelection &&
        other.routeId == routeId &&
        other.busId == busId;
  }

  @override
  int get hashCode => Object.hash(routeId, busId);
}
