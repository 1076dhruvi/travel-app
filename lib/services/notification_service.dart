import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(settings);

    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleNoteReminder({
    required int id,
    required String title,
    required String content,
    required DateTime reminderTime,
  }) async {
    if (reminderTime.isBefore(DateTime.now())) {
      return;
    }

    final scheduledTime =
    tz.TZDateTime.from(reminderTime, tz.local);

    await _notifications.zonedSchedule(
      id,
      title,
      content,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'note_reminders',
          'Note Reminders',
          channelDescription: 'Reminders for travel notes',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelNoteReminder(int id) async {
    await _notifications.cancel(id);
  }
}