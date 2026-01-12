import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'models.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print('Notification tapped: ${details.payload}');
      },
    );

    // Request exact alarm permission
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      // Request exact alarms permission
      final granted = await androidImpl.requestExactAlarmsPermission();
      print('Exact alarms permission: $granted');

      // Check if can schedule exact alarms
      final canSchedule = await androidImpl.canScheduleExactNotifications();
      print('Can schedule exact notifications: $canSchedule');
    }
  }

  static Future<void> scheduleTaskNotification(Task task) async {
    if (task.id == null || task.isCompleted) return;

    final now = DateTime.now();
    final scheduledDate = task.deadlineDateTime;

    print('⏰ Current time: $now');
    print('📅 Scheduling notifications for: ${task.title}');
    print('   Deadline: $scheduledDate');

    if (scheduledDate.isBefore(now)) {
      print('⚠️ Task deadline is in the past: ${task.title}');
      return;
    }

    // Determine importance based on priority
    final importance = _getImportanceFromPriority(task.priority);
    final priority = _getPriorityFromTaskPriority(task.priority);

    // 1. Notify 1 day before
    final oneDayBefore = scheduledDate.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      final tzTime = tz.TZDateTime.from(oneDayBefore, tz.local);
      print('   Scheduling 1 day before: $oneDayBefore (TZ: $tzTime)');

      await _notifications.zonedSchedule(
        task.id.hashCode,
        '📅 Nhắc nhở: ${task.title}',
        'Còn 1 ngày nữa là đến hạn.',
        tz.TZDateTime.from(oneDayBefore, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders_day',
            'Nhắc nhở 1 ngày trước',
            channelDescription: 'Thông báo nhắc nhở 1 ngày trước khi đến hạn',
            importance: importance,
            priority: priority,
            playSound: true,
            enableVibration: true,
            actions: [
              AndroidNotificationAction('snooze_5', 'Snooze 5 min'),
              AndroidNotificationAction('snooze_15', 'Snooze 15 min'),
              AndroidNotificationAction('done', 'Mark Done'),
            ],
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('   ✅ Scheduled: 1 day before at $oneDayBefore');
    }

    // 2. Notify 3 hours before
    final threeHoursBefore = scheduledDate.subtract(const Duration(hours: 3));
    if (threeHoursBefore.isAfter(now)) {
      final tzTime = tz.TZDateTime.from(threeHoursBefore, tz.local);
      print('   Scheduling 3 hours before: $threeHoursBefore (TZ: $tzTime)');

      await _notifications.zonedSchedule(
        task.id.hashCode + 1,
        '⏰ Sắp đến hạn: ${task.title}',
        'Còn 3 giờ nữa là đến giờ.',
        tz.TZDateTime.from(threeHoursBefore, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders_3h',
            'Nhắc nhở 3 giờ trước',
            channelDescription: 'Thông báo nhắc nhở 3 giờ trước khi đến hạn',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('   ✅ Scheduled: 3 hours before at $threeHoursBefore');
    }

    // 3. Notify 30 minutes before
    final thirtyMinsBefore = scheduledDate.subtract(
      const Duration(minutes: 30),
    );
    if (thirtyMinsBefore.isAfter(now)) {
      final tzTime = tz.TZDateTime.from(thirtyMinsBefore, tz.local);
      print('   Scheduling 30 minutes before: $thirtyMinsBefore (TZ: $tzTime)');

      await _notifications.zonedSchedule(
        task.id.hashCode + 2,
        '⚠️ Gần đến hạn: ${task.title}',
        'Còn 30 phút nữa là đến giờ rồi!',
        tz.TZDateTime.from(thirtyMinsBefore, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders_30m',
            'Nhắc nhở 30 phút trước',
            channelDescription: 'Thông báo nhắc nhở 30 phút trước khi đến hạn',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('   ✅ Scheduled: 30 minutes before at $thirtyMinsBefore');
    }

    // 4. Notify at exact time
    final tzTime = tz.TZDateTime.from(scheduledDate, tz.local);
    print('   Scheduling exact time: $scheduledDate (TZ: $tzTime)');

    await _notifications.zonedSchedule(
      task.id.hashCode + 3,
      '🔴 ĐẾN HẠN: ${task.title}',
      task.description.isNotEmpty
          ? task.description
          : 'Công việc đã đến hạn. Hãy hoàn thành ngay!',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Nhắc nhở công việc',
          channelDescription: 'Thông báo khi đến giờ làm việc',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    print('   ✅ Scheduled: Exact time at $scheduledDate');
  }

  static Future<void> cancelNotification(String taskId) async {
    await _notifications.cancel(taskId.hashCode);
    await _notifications.cancel(taskId.hashCode + 1);
    await _notifications.cancel(taskId.hashCode + 2);
    await _notifications.cancel(taskId.hashCode + 3);
  }

  static Importance _getImportanceFromPriority(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Importance.max;
      case TaskPriority.medium:
        return Importance.high;
      case TaskPriority.low:
        return Importance.defaultImportance;
    }
  }

  static Priority _getPriorityFromTaskPriority(TaskPriority taskPriority) {
    switch (taskPriority) {
      case TaskPriority.high:
        return Priority.max;
      case TaskPriority.medium:
        return Priority.high;
      case TaskPriority.low:
        return Priority.defaultPriority;
    }
  }

  static Future<void> snoozeNotification(String taskId, int minutes) async {
    await cancelNotification(taskId);
    final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
    
    await _notifications.zonedSchedule(
      taskId.hashCode + 999,
      '⏰ Snoozed Reminder',
      'Time to check your task!',
      tz.TZDateTime.from(snoozeTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'snooze_reminders',
          'Snoozed Reminders',
          channelDescription: 'Reminders that were snoozed',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
