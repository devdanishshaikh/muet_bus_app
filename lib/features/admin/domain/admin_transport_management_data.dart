class AdminBus {
  const AdminBus({
    this.id,
    required this.busNumber,
    required this.busName,
    required this.status,
  });

  final String? id;
  final String busNumber;
  final String busName;
  final String status;
}

class AdminDriver {
  const AdminDriver({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
  });

  final String id;
  final String name;
  final String? phone;
  final String status;
}

class AdminRoute {
  const AdminRoute({
    this.id,
    required this.name,
    required this.description,
    required this.status,
  });

  final String? id;
  final String name;
  final String? description;
  final String status;
}

class AdminStop {
  const AdminStop({
    this.id,
    required this.routeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.stopOrder,
  });

  final String? id;
  final String routeId;
  final String name;
  final double latitude;
  final double longitude;
  final int stopOrder;
}

class AdminBusDriverAssignment {
  const AdminBusDriverAssignment({
    required this.id,
    required this.busId,
    required this.busName,
    required this.driverId,
    required this.driverName,
    required this.active,
  });

  final String id;
  final String busId;
  final String busName;
  final String driverId;
  final String driverName;
  final bool active;
}

class AdminBusRouteAssignment {
  const AdminBusRouteAssignment({
    required this.id,
    required this.busId,
    required this.busName,
    required this.routeId,
    required this.routeName,
    required this.active,
  });

  final String id;
  final String busId;
  final String busName;
  final String routeId;
  final String routeName;
  final bool active;
}

class AdminRouteSchedule {
  const AdminRouteSchedule({
    this.id,
    required this.routeId,
    required this.routeName,
    required this.stopId,
    required this.stopName,
    required this.dayOfWeek,
    required this.scheduledTime,
  });

  final String? id;
  final String routeId;
  final String routeName;
  final String stopId;
  final String stopName;
  final int dayOfWeek;
  final String scheduledTime;
}
