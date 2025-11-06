import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize time zones
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        // Handle notification tap when app is in foreground
      },
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap when app is in background/terminated
        // You can navigate to specific screen based on payload
      },
    );

    _isInitialized = true;
  }

  // Show a simple notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    DateTime? scheduledTime,
  }) async {
    if (!_isInitialized) await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'token_updates_channel',
      'Token Updates',
      channelDescription: 'Notifications for token status updates',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      showWhen: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    if (scheduledTime != null) {
      // Schedule notification for a specific time
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        platformDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } else {
      // Show notification immediately
      await _notifications.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    }
  }

  // Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Handle token status change notification
  Future<void> handleTokenStatusChange({
    required String tokenNumber,
    required String newStatus,
    String? additionalInfo,
  }) async {
    String title = 'Token $tokenNumber';
    String body = '';

    switch (newStatus.toLowerCase()) {
      case 'processing':
        body = 'Your token is now being processed';
        break;
      case 'completed':
        body = 'Your token has been completed';
        break;
      case 'cancelled':
        body = 'Your token has been cancelled';
        break;
      case 'next_in_line':
        body = 'You are next in line! Please be ready.';
        break;
      default:
        body = additionalInfo ?? 'Status updated: $newStatus';
    }

    await showNotification(
      id: tokenNumber.hashCode,
      title: title,
      body: body,
      payload: 'token:$tokenNumber',
    );
  }
}