import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class StudentNotificationGateway {
  Future<bool> initializeAndRequestPermission();

  Future<bool> showBusArrival({
    required String eventKey,
    required String busNumber,
    required String stopName,
    String? routeName,
    String? tripId,
  });

  Future<void> cancelNotification(String eventKey);

  Future<void> cancelAllNotifications();
}

class StudentNotificationService implements StudentNotificationGateway {
  StudentNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    this._onNotificationTap,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(String? payload)? _onNotificationTap;

  bool _initialized = false;
  bool? _permissionGranted;

  bool? get permissionGranted => _permissionGranted;

  static const String _channelId = 'bus_arrivals';
  static const String _channelName = 'Bus Arrivals';
  static const String _channelDescription = 'Alerts for selected bus stops.';

  @override
  Future<bool> initializeAndRequestPermission() async {
    if (_permissionGranted != null) {
      return _permissionGranted!;
    }

    try {
      if (!_initialized) {
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosSettings = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        const settings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );

        final initialized = await _plugin.initialize(
          settings,
          onDidReceiveNotificationResponse: (response) {
            final payload = response.payload;
            debugPrint('Notification tapped with payload: $payload');
            if (payload != null) {
              _onNotificationTap?.call(payload);
            }
          },
        ) ?? false;

        if (!initialized) {
          _permissionGranted = false;
          return false;
        }
        _initialized = true;
      }

      // Create notification channel for Android
      await _createNotificationChannel();

      // Request permissions
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission() ?? false;
        _permissionGranted = granted;
        return granted;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ?? false;
        _permissionGranted = granted;
        return granted;
      }

      _permissionGranted = true;
      return true;
    } catch (e) {
      debugPrint('Notification initialization failed: $e');
      _permissionGranted = false;
      return false;
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  @override
  Future<bool> showBusArrival({
    required String eventKey,
    required String busNumber,
    required String stopName,
    String? routeName,
    String? tripId,
  }) async {
    if (!await initializeAndRequestPermission()) {
      debugPrint('Notification permission not granted');
      return false;
    }

    final notificationId = _notificationId(eventKey);
    final payload = _createPayload(
      eventKey: eventKey,
      tripId: tripId,
      busNumber: busNumber,
      stopName: stopName,
      routeName: routeName,
    );

    try {
      await _plugin.show(
        notificationId,
        'Bus arriving soon',
        '$busNumber is approaching $stopName${routeName != null ? ' on $routeName' : ''}.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('Failed to show notification: $e');
      return false;
    }
  }

  @override
  Future<void> cancelNotification(String eventKey) async {
    final notificationId = _notificationId(eventKey);
    await _plugin.cancel(notificationId);
  }

  @override
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  String _createPayload({
    required String eventKey,
    String? tripId,
    required String busNumber,
    required String stopName,
    String? routeName,
  }) {
    final buffer = StringBuffer();
    buffer.write('eventKey=$eventKey');
    if (tripId != null) buffer.write('&tripId=$tripId');
    buffer.write('&busNumber=${Uri.encodeComponent(busNumber)}');
    buffer.write('&stopName=${Uri.encodeComponent(stopName)}');
    if (routeName != null) buffer.write('&routeName=${Uri.encodeComponent(routeName)}');
    return buffer.toString();
  }

  int _notificationId(String eventKey) {
    var value = 0;
    for (final codeUnit in eventKey.codeUnits) {
      value = (value * 31 + codeUnit) & 0x7fffffff;
    }
    return value;
  }
}