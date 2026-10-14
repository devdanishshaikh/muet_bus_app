import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class StudentNotificationGateway {
  Future<bool> showBusArrival({
    required String eventKey,
    required String busNumber,
    required String stopName,
  });
}

class StudentNotificationService implements StudentNotificationGateway {
  StudentNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool? _permissionGranted;

  bool? get permissionGranted => _permissionGranted;

  Future<bool> initializeAndRequestPermission() async {
    if (_permissionGranted != null) {
      return _permissionGranted!;
    }

    try {
      if (!_initialized) {
        final settings = InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: const DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        );
        final initialized = await _plugin.initialize(settings) ?? false;
        if (!initialized) {
          _permissionGranted = false;
          return false;
        }
        _initialized = true;
      }

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        _permissionGranted =
            await android.requestNotificationsPermission() ?? false;
        return _permissionGranted!;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        _permissionGranted =
            await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        return _permissionGranted!;
      }

      _permissionGranted = true;
      return true;
    } catch (_) {
      _permissionGranted = false;
      return false;
    }
  }

  @override
  Future<bool> showBusArrival({
    required String eventKey,
    required String busNumber,
    required String stopName,
  }) async {
    if (!await initializeAndRequestPermission()) {
      return false;
    }

    final notificationId = _notificationId(eventKey);
    try {
      await _plugin.show(
        notificationId,
        'Bus arriving soon',
        '$busNumber is entering the radius for $stopName.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'bus_arrivals',
            'Bus arrivals',
            channelDescription: 'Alerts for selected bus stops.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  int _notificationId(String eventKey) {
    var value = 0;
    for (final codeUnit in eventKey.codeUnits) {
      value = (value * 31 + codeUnit) & 0x7fffffff;
    }
    return value;
  }
}
