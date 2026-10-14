class StudentRoute {
  const StudentRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.stops,
  });

  final String id;
  final String name;
  final String? description;
  final String status;
  final List<StudentRouteStop> stops;
}

class StudentRouteStop {
  const StudentRouteStop({
    required this.id,
    required this.name,
    required this.stopOrder,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final int stopOrder;
  final double? latitude;
  final double? longitude;
}

class ActiveRouteBus {
  const ActiveRouteBus({
    this.busId,
    required this.busNumber,
    required this.busName,
    required this.status,
  });

  final String? busId;
  final String busNumber;
  final String busName;
  final String status;
}

class StudentRouteDetails {
  const StudentRouteDetails({required this.route, this.activeBus});

  final StudentRoute route;
  final ActiveRouteBus? activeBus;
}
