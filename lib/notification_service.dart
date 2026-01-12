// Import các thư viện cần thiết
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Thông báo local
import 'package:timezone/timezone.dart' as tz; // Múi giờ
import 'package:timezone/data/latest.dart' as tz; // Dữ liệu múi giờ
import 'models.dart'; // Model Task

/// Dịch vụ thông báo thông minh
/// Tự động gửi thông báo nhắc nhở nhiệm vụ ở 4 thời điểm:
/// - 1 ngày trước
/// - 3 giờ trước  
/// - 30 phút trước
/// - Đúng giờ deadline
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Khởi tạo dịch vụ thông báo
  static Future<void> init() async {
    // Khởi tạo múi giờ và đặt múi giờ Việt Nam
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    // Cài đặt cho Android
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // Cài đặt cho iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Khởi tạo plugin với callback khi tap vào thông báo
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print('Notification tapped: ${details.payload}');
      },
    );

    // Yêu cầu quyền hẹn giờ chính xác (Android 12+)
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      // Yêu cầu quyền hẹn giờ chính xác
      final granted = await androidImpl.requestExactAlarmsPermission();
      print('Quyền hẹn giờ chính xác: $granted');

      // Kiểm tra có thể hẹn giờ chính xác không
      final canSchedule = await androidImpl.canScheduleExactNotifications();
      print('Có thể hẹn giờ thông báo chính xác: $canSchedule');
    }
  }

  /// Hẹn giờ gửi thông báo cho nhiệm vụ (4 lần nhắc)
  static Future<void> scheduleTaskNotification(Task task) async {
    if (task.id == null || task.isCompleted) return;

    final now = DateTime.now();
    final scheduledDate = task.deadlineDateTime;

    print('⏰ Thời gian hiện tại: $now');
    print('📅 Đang hẹn giờ thông báo cho: ${task.title}');
    print('   Deadline: $scheduledDate');

    if (scheduledDate.isBefore(now)) {
      print('⚠️ Deadline đã qua: ${task.title}');
      return;
    }

    // Xác định mức độ quan trọng dựa trên priority
    final importance = _getImportanceFromPriority(task.priority);
    final priority = _getPriorityFromTaskPriority(task.priority);

    // 1. Thông báo 1 ngày trước
    final oneDayBefore = scheduledDate.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      final tzTime = tz.TZDateTime.from(oneDayBefore, tz.local);
      print('   Đang hẹn giờ cho 1 ngày trước: $oneDayBefore (TZ: $tzTime)');

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
              AndroidNotificationAction('snooze_5', 'Hoãn 5 phút'),
              AndroidNotificationAction('snooze_15', 'Hoãn 15 phút'),
              AndroidNotificationAction('done', 'Đánh dấu xong'),
            ],
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('   ✅ Đã hẹn: 1 ngày trước lúc $oneDayBefore');
    }

    // 2. Thông báo 3 giờ trước
    final threeHoursBefore = scheduledDate.subtract(const Duration(hours: 3));
    if (threeHoursBefore.isAfter(now)) {
      final tzTime = tz.TZDateTime.from(threeHoursBefore, tz.local);
      print('   Đang hẹn giờ cho 3 giờ trước: $threeHoursBefore (TZ: $tzTime)');

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
      print('   ✅ Đã hẹn: 3 giờ trước lúc $threeHoursBefore');
    }

    // 3. Thông báo 30 phút trước
    final thirtyMinsBefore = scheduledDate.subtract(
      const Duration(minutes: 30),
    );
    if (thirtyMinsBefore.isAfter(now)) {
      final tzTime = tz.TZDateTime.from(thirtyMinsBefore, tz.local);
      print('   Đang hẹn giờ cho 30 phút trước: $thirtyMinsBefore (TZ: $tzTime)');

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
      print('   ✅ Đã hẹn: 30 phút trước lúc $thirtyMinsBefore');
    }

    // 4. Thông báo đúng giờ deadline
    final tzTime = tz.TZDateTime.from(scheduledDate, tz.local);
    print('   Đang hẹn giờ cho đúng deadline: $scheduledDate (TZ: $tzTime)');

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
    print('   ✅ Đã hẹn: Đúng giờ lúc $scheduledDate');
  }

  /// Hủy tất cả thông báo của một task
  static Future<void> cancelNotification(String taskId) async {
    await _notifications.cancel(taskId.hashCode);     // Hủy thông báo 1 ngày trước
    await _notifications.cancel(taskId.hashCode + 1); // Hủy thông báo 3 giờ trước
    await _notifications.cancel(taskId.hashCode + 2); // Hủy thông báo 30 phút trước
    await _notifications.cancel(taskId.hashCode + 3); // Hủy thông báo đúng giờ
  }

  /// Chuyển đổi TaskPriority sang Importance của Android
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

  /// Chuyển đổi TaskPriority sang Priority của Android
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

  /// Hoãn thông báo (snooze) - hủy thông báo hiện tại và hẹn lại sau X phút
  static Future<void> snoozeNotification(String taskId, int minutes) async {
    await cancelNotification(taskId);
    final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
    
    await _notifications.zonedSchedule(
      taskId.hashCode + 999,
      '⏰ Nhắc lại',
      'Đã đến giờ kiểm tra nhiệm vụ!',
      tz.TZDateTime.from(snoozeTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'snooze_reminders',
          'Nhắc lại',
          channelDescription: 'Thông báo đã được hoãn',
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
