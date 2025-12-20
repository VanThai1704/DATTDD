import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' as scheduler;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// Model cho Event
class Event {
  final String? id; // ID từ Firestore
  final String title;
  final String time;
  final DateTime? date;
  final IconData icon;
  final Color color;

  Event({
    this.id,
    required this.title,
    required this.time,
    this.date,
    required this.icon,
    required this.color,
  });

  // Chuyển đổi Event thành Map để lưu vào JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'time': time,
      'date': date?.toIso8601String(),
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'colorValue': color.value,
    };
  }

  // Tạo Event từ Map (từ Firestore)
  factory Event.fromFirestore(Map<String, dynamic> json, String? id) {
    return Event(
      id: id,
      title: json['title'] as String,
      time: json['time'] as String,
      date: json['date'] != null ? (json['date'] as Timestamp).toDate() : null,
      icon: IconData(
        json['iconCodePoint'] as int,
        fontFamily: json['iconFontFamily'] as String?,
        fontPackage: json['iconFontPackage'] as String?,
      ),
      color: Color(json['colorValue'] as int),
    );
  }
}

// Model cho Task
class Task {
  final String? id; // ID từ Firestore
  final String title;
  final String deadline;

  Task({
    this.id,
    required this.title,
    required this.deadline,
  });

  // Chuyển đổi Task thành Map để lưu vào Firestore
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'deadline': deadline,
    };
  }

  // Tạo Task từ Map (từ Firestore)
  factory Task.fromFirestore(Map<String, dynamic> json, String? id) {
    return Task(
      id: id,
      title: json['title'] as String,
      deadline: json['deadline'] as String,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Notification plugin
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  int _notificationId = 0;
  Timer? _notificationTimer;
  // Map để lưu thời gian gửi thông báo cuối cùng cho mỗi event
  // Key format: 'eventKey_notificationType' (ví dụ: 'eventKey_60', 'eventKey_30', 'eventKey_15', 'eventKey_5', 'eventKey_start')
  // Value: DateTime của lần gửi thông báo cuối cùng
  final Map<String, DateTime> _lastNotificationTime = {};
  // Map để lưu thời gian gửi thông báo cuối cùng cho mỗi task
  final Map<String, DateTime> _lastTaskNotificationTime = {};
  
  // Khoảng thời gian giữa các lần gửi thông báo lặp lại (tính bằng phút)
  // Giảm xuống để gửi liên tục hơn
  static const int _repeatNotificationInterval = 1; // Gửi lại mỗi 1 phút

  // Danh sách events và tasks (lưu trong memory)
  final List<Event> _events = [];
  final List<Task> _tasks = [];

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _eventsSubscription;
  StreamSubscription<QuerySnapshot>? _tasksSubscription;
  bool _isDisposed = false; // Flag để đánh dấu widget đã dispose

  // Helper method để gọi setState một cách an toàn
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      try {
        setState(fn);
      } catch (e) {
        debugPrint('Lỗi khi gọi setState: $e');
      }
    }
  }

  // Helper method để schedule frame callback an toàn (không tạo widget dependency)
  void _safeScheduleFrameCallback(VoidCallback callback) {
    if (!_isDisposed && mounted) {
      try {
        scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && mounted) {
            callback();
          }
        });
      } catch (e) {
        debugPrint('Lỗi khi schedule frame callback: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startNotificationChecker();
    // Load dữ liệu ngay lập tức - chỉ đợi frame đầu tiên để đảm bảo widget đã mounted
    scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _setupFirestoreListeners();
      }
    });
  }

  @override
  void dispose() {
    // Đánh dấu widget đã dispose TRƯỚC khi cancel subscriptions
    // Điều này đảm bảo không có callback nào có thể gọi setState sau khi dispose
    _isDisposed = true;
    
    // Cancel tất cả subscriptions ngay lập tức và đảm bảo không có callback nào chạy
    try {
      _notificationTimer?.cancel();
      _notificationTimer = null;
      
      // Cancel subscriptions ngay lập tức (không pause vì có thể gây race condition)
      _eventsSubscription?.cancel();
      _eventsSubscription = null;
      
      _tasksSubscription?.cancel();
      _tasksSubscription = null;
    } catch (e) {
      debugPrint('Lỗi khi cancel subscriptions trong dispose: $e');
    }
    
    super.dispose();
  }

  // Khởi tạo notification
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true, // Yêu cầu quyền critical notification (iOS)
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Xử lý khi người dùng tap vào notification
      },
    );

    // Yêu cầu quyền trên Android 13+
    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      // Tạo notification channel với sound và vibration
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          'time_management_channel',
          'Time Management',
          description: 'Thông báo về thời khóa biểu với chuông báo thức',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
        ),
      );
    }
  }

  // Bắt đầu kiểm tra thông báo định kỳ
  void _startNotificationChecker() {
    debugPrint('🚀 Bắt đầu kiểm tra thông báo định kỳ');
    // Kiểm tra mỗi 10 giây để thông báo liên tục và chính xác hơn
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isDisposed && mounted) {
        _checkUpcomingEvents();
        _checkUpcomingTasks();
      } else {
        debugPrint('⚠️ Dừng timer: Widget disposed hoặc không mounted');
        timer.cancel();
      }
    });
    // Kiểm tra ngay lập tức
    if (!_isDisposed && mounted) {
      debugPrint('🔍 Kiểm tra thông báo ngay lập tức');
      _checkUpcomingEvents();
      _checkUpcomingTasks();
    }
  }

  // Kiểm tra các sự kiện sắp tới và gửi thông báo
  void _checkUpcomingEvents() {
    // Kiểm tra disposed và mounted trước khi xử lý
    if (_isDisposed || !mounted) {
      debugPrint('⚠️ _checkUpcomingEvents: Widget disposed hoặc không mounted');
      return;
    }
    
    final now = DateTime.now();
    debugPrint('🔔 Kiểm tra thông báo lúc ${now.hour}:${now.minute}:${now.second} - Có ${_events.length} events');
    
    if (_events.isEmpty) {
      debugPrint('⚠️ Không có events nào để kiểm tra');
      return;
    }
    
    for (int i = 0; i < _events.length; i++) {
      final event = _events[i];
      if (event.date == null) {
        debugPrint('⚠️ Event "${event.title}" không có ngày');
        continue;
      }
      
      // Parse giờ bắt đầu từ event.time
      final startTime = _parseTimeFromString(event.time);
      if (startTime == null) {
        debugPrint('⚠️ Không parse được thời gian cho event "${event.title}": ${event.time}');
        continue;
      }
      
      // Tạo DateTime cho thời điểm bắt đầu sự kiện
      final eventDateTime = DateTime(
        event.date!.year,
        event.date!.month,
        event.date!.day,
        startTime.hour,
        startTime.minute,
      );
      
      // Tính khoảng cách thời gian
      final difference = eventDateTime.difference(now);
      final minutesUntilEvent = difference.inMinutes;
      final secondsUntilEvent = difference.inSeconds;
      
      debugPrint('📅 Event: "${event.title}" - Còn $minutesUntilEvent phút (${secondsUntilEvent} giây)');
      
      // Tạo key duy nhất cho event (để tránh thông báo trùng lặp)
      final eventKey = '${event.title}_${eventDateTime.millisecondsSinceEpoch}';
      final startEventKey = '${eventKey}_start';
      
      // Gửi thông báo liên tục khi còn dưới 60 phút
      if (minutesUntilEvent > 0 && minutesUntilEvent <= 60) {
        final notificationKey = '${eventKey}_continuous';
        final lastNotification = _lastNotificationTime[notificationKey];
        
        // Gửi lại mỗi 1 phút khi còn dưới 60 phút
        // Gửi mỗi 30 giây khi còn dưới 10 phút
        // Gửi mỗi 15 giây khi còn dưới 2 phút
        int repeatIntervalSeconds;
        if (minutesUntilEvent <= 2) {
          repeatIntervalSeconds = 15; // Gửi mỗi 15 giây khi còn dưới 2 phút
        } else if (minutesUntilEvent <= 10) {
          repeatIntervalSeconds = 30; // Gửi mỗi 30 giây khi còn dưới 10 phút
        } else {
          repeatIntervalSeconds = 60; // Gửi mỗi 1 phút khi còn dưới 60 phút
        }
        
        final shouldSend = lastNotification == null || 
            now.difference(lastNotification).inSeconds >= repeatIntervalSeconds;
        
        if (shouldSend) {
          String timeText;
          if (minutesUntilEvent >= 60) {
            final hours = minutesUntilEvent ~/ 60;
            timeText = hours == 1 ? '1 giờ' : '$hours giờ';
          } else if (minutesUntilEvent == 0) {
            timeText = 'ít hơn 1 phút';
          } else if (minutesUntilEvent == 1) {
            timeText = '1 phút';
          } else {
            timeText = '$minutesUntilEvent phút';
          }
          
          debugPrint('✅ Gửi thông báo liên tục: "${event.title}" còn $timeText (gửi lại sau $repeatIntervalSeconds giây)');
          _showNotification(
            'Sự kiện sắp tới',
            '${event.title} sẽ bắt đầu trong $timeText',
          );
          _lastNotificationTime[notificationKey] = now;
        }
      }
      
      // Gửi thông báo liên tục khi đã đến giờ (trong vòng 10 phút đầu)
      if (minutesUntilEvent == 0 && secondsUntilEvent >= 0 && secondsUntilEvent <= 600) {
        final notificationKey = startEventKey;
        final lastNotification = _lastNotificationTime[notificationKey];
        
        // Gửi lại mỗi 30 giây khi event đã bắt đầu
        final shouldSend = lastNotification == null || 
            now.difference(lastNotification).inSeconds >= 30;
        
        if (shouldSend) {
          debugPrint('✅ Gửi thông báo event đã bắt đầu: "${event.title}"');
          _showNotification(
            'Sự kiện đã bắt đầu',
            '${event.title} đã bắt đầu lúc ${_formatTimeOfDay(startTime)}',
          );
          _lastNotificationTime[notificationKey] = now;
        }
      }
      
      // Xóa các event đã qua khỏi map (dọn dẹp) - sau 10 phút kể từ khi event bắt đầu
      if (minutesUntilEvent < -10) {
        // Xóa tất cả các notification keys liên quan
        _lastNotificationTime.remove('${eventKey}_continuous');
        _lastNotificationTime.remove(startEventKey);
      }
    }
  }

  // Kiểm tra các task sắp đến deadline và gửi thông báo
  void _checkUpcomingTasks() {
    if (_isDisposed || !mounted) {
      return;
    }
    
    final now = DateTime.now();
    
    for (int i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      
      // Parse deadline từ task.deadline (format: "Hạn chót: DD/MM/YYYY")
      final deadlineText = task.deadline.replaceFirst('Hạn chót: ', '').trim();
      DateTime? deadlineDate;
      
      try {
        // Thử parse format DD/MM/YYYY
        final parts = deadlineText.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          deadlineDate = DateTime(year, month, day, 23, 59); // Cuối ngày
        }
      } catch (e) {
        debugPrint('Lỗi khi parse deadline: $e');
        continue;
      }
      
      if (deadlineDate == null) continue;
      
      // Tính khoảng cách thời gian
      final difference = deadlineDate.difference(now);
      final daysUntilDeadline = difference.inDays;
      final hoursUntilDeadline = difference.inHours;
      
      // Tạo key duy nhất cho task
      final taskKey = '${task.title}_${deadlineDate.millisecondsSinceEpoch}';
      
      // Gửi thông báo 1 ngày trước deadline và lặp lại
      if (daysUntilDeadline == 1 && hoursUntilDeadline >= 23 && hoursUntilDeadline <= 24) {
        final notificationKey = '${taskKey}_1day';
        final lastNotification = _lastTaskNotificationTime[notificationKey];
        final shouldSend = lastNotification == null || 
            now.difference(lastNotification).inHours >= 6; // Gửi lại mỗi 6 giờ
        
        if (shouldSend) {
          _showNotification(
            'Nhiệm vụ sắp đến hạn',
            '${task.title} còn 1 ngày nữa đến hạn chót',
          );
          _lastTaskNotificationTime[notificationKey] = now;
        }
      }
      
      // Gửi thông báo khi còn 12 giờ trước deadline và lặp lại
      if (daysUntilDeadline == 0 && hoursUntilDeadline > 0 && hoursUntilDeadline <= 12) {
        final notificationKey = '${taskKey}_12hours';
        final lastNotification = _lastTaskNotificationTime[notificationKey];
        final shouldSend = lastNotification == null || 
            now.difference(lastNotification).inHours >= 3; // Gửi lại mỗi 3 giờ
        
        if (shouldSend) {
          String timeText;
          if (hoursUntilDeadline == 1) {
            timeText = '1 giờ';
          } else {
            timeText = '$hoursUntilDeadline giờ';
          }
          
          _showNotification(
            'Nhiệm vụ sắp đến hạn',
            '${task.title} còn $timeText nữa đến hạn chót',
          );
          _lastTaskNotificationTime[notificationKey] = now;
        }
      }
      
      // Gửi thông báo khi đến deadline (trong vòng 24 giờ đầu) và lặp lại
      if (daysUntilDeadline == 0 && hoursUntilDeadline >= 0 && hoursUntilDeadline <= 24) {
        final notificationKey = '${taskKey}_deadline';
        final lastNotification = _lastTaskNotificationTime[notificationKey];
        final shouldSend = lastNotification == null || 
            now.difference(lastNotification).inHours >= 2; // Gửi lại mỗi 2 giờ
        
        if (shouldSend) {
          String message;
          if (hoursUntilDeadline == 0) {
            message = '${task.title} đã đến hạn chót hôm nay';
          } else {
            message = '${task.title} còn $hoursUntilDeadline giờ nữa đến hạn chót';
          }
          
          _showNotification(
            'Nhiệm vụ đến hạn',
            message,
          );
          _lastTaskNotificationTime[notificationKey] = now;
        }
      }
      
      // Xóa các task đã qua deadline khỏi map (dọn dẹp)
      if (daysUntilDeadline < 0 || (daysUntilDeadline == 0 && hoursUntilDeadline < 0)) {
        _lastTaskNotificationTime.remove('${taskKey}_1day');
        _lastTaskNotificationTime.remove('${taskKey}_12hours');
        _lastTaskNotificationTime.remove('${taskKey}_deadline');
      }
    }
  }

  // Gửi thông báo với chuông báo như báo thức
  Future<void> _showNotification(String title, String body, {bool isAlarm = true}) async {
    // Kiểm tra disposed trước khi gửi thông báo
    if (_isDisposed) {
      debugPrint('⚠️ Không thể gửi thông báo: Widget đã disposed');
      return;
    }
    
    debugPrint('🔔 Đang gửi thông báo: $title - $body');
    
    try {
      // Android notification với chuông báo thức
      final androidDetails = AndroidNotificationDetails(
        'time_management_channel',
        'Time Management',
        channelDescription: 'Thông báo về thời khóa biểu',
        importance: Importance.max, // Tối đa để hiển thị ngay cả khi màn hình tắt
        priority: Priority.max, // Ưu tiên cao nhất
        showWhen: true,
        enableVibration: true,
        vibrationPattern: isAlarm 
            ? Int64List.fromList([0, 500, 200, 500, 200, 500]) // Rung mạnh như báo thức
            : Int64List.fromList([0, 250, 250, 250]), // Rung nhẹ cho thông báo thường
        playSound: true,
        // Dùng sound mặc định của hệ thống (notification sound)
        // Android sẽ tự động dùng sound mặc định khi không chỉ định
        category: isAlarm 
            ? AndroidNotificationCategory.alarm // Phân loại là alarm
            : AndroidNotificationCategory.reminder,
        fullScreenIntent: isAlarm, // Hiển thị full screen khi màn hình tắt (chỉ cho alarm)
        autoCancel: false, // Không tự động tắt để người dùng phải chủ động tắt
        ongoing: isAlarm, // Đánh dấu là ongoing notification (không thể swipe away)
        styleInformation: BigTextStyleInformation(body), // Hiển thị text lớn
      );

      // iOS notification với sound
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default', // Dùng sound mặc định của iOS
        interruptionLevel: InterruptionLevel.critical, // Critical để hiển thị ngay cả khi Do Not Disturb
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = _notificationId++;
      await _notifications.show(
        notificationId,
        title,
        body,
        details,
      );
      debugPrint('✅ Đã gửi thông báo thành công (ID: $notificationId)');
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi thông báo: $e');
    }
  }

  // Thiết lập listeners cho Firestore để tự động cập nhật khi có thay đổi
  void _setupFirestoreListeners() {
    if (_isDisposed || !mounted) return;
    
    // Kiểm tra Firebase đã được khởi tạo chưa
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('Firebase chưa được khởi tạo, thử lại ngay lập tức');
        // Thử lại ngay lập tức với microtask
        Future.microtask(() {
          if (!_isDisposed && mounted) {
            _setupFirestoreListeners();
          }
        });
        return;
      }
    } catch (e) {
      debugPrint('Lỗi khi kiểm tra Firebase: $e');
      // Thử lại ngay lập tức với microtask
      Future.microtask(() {
        if (!_isDisposed && mounted) {
          _setupFirestoreListeners();
        }
      });
      return;
    }
    
    try {
      // Listen cho Events
      _eventsSubscription?.cancel(); // Cancel subscription cũ nếu có
      _eventsSubscription = _firestore.collection('events').snapshots().listen(
        (snapshot) {
          // Kiểm tra disposed và mounted ngay đầu callback
          if (_isDisposed || !mounted) {
            return;
          }
          
          // Parse dữ liệu trước
          final newEvents = <Event>[];
          for (var doc in snapshot.docs) {
            try {
              newEvents.add(Event.fromFirestore(doc.data(), doc.id));
            } catch (e) {
              debugPrint('Lỗi khi parse event: $e');
            }
          }
          
          // Cập nhật UI ngay lập tức nếu widget vẫn mounted
          if (!_isDisposed && mounted) {
            try {
              // Sử dụng helper method để gọi setState an toàn
              _safeSetState(() {
                _events.clear();
                _events.addAll(newEvents);
              });
            } catch (e) {
              debugPrint('Lỗi khi xử lý events: $e');
            }
          }
        },
        onError: (error) {
          debugPrint('Lỗi khi listen events: $error');
        },
        cancelOnError: false,
      );

      // Listen cho Tasks
      _tasksSubscription?.cancel(); // Cancel subscription cũ nếu có
      _tasksSubscription = _firestore.collection('tasks').snapshots().listen(
        (snapshot) {
          // Kiểm tra disposed và mounted ngay đầu callback
          if (_isDisposed || !mounted) {
            return;
          }
          
          // Parse dữ liệu trước
          final newTasks = <Task>[];
          for (var doc in snapshot.docs) {
            try {
              newTasks.add(Task.fromFirestore(doc.data(), doc.id));
            } catch (e) {
              debugPrint('Lỗi khi parse task: $e');
            }
          }
          
          // Cập nhật UI ngay lập tức nếu widget vẫn mounted
          if (!_isDisposed && mounted) {
            try {
              // Sử dụng helper method để gọi setState an toàn
              _safeSetState(() {
                _tasks.clear();
                _tasks.addAll(newTasks);
              });
            } catch (e) {
              debugPrint('Lỗi khi xử lý tasks: $e');
            }
          }
        },
        onError: (error) {
          debugPrint('Lỗi khi listen tasks: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Lỗi khi setup Firestore listeners: $e');
    }
  }

  // Lưu Event vào Firestore
  Future<void> _saveEvent(Event event) async {
    // Kiểm tra disposed trước khi lưu
    if (_isDisposed || !mounted) {
      return;
    }
    
    try {
      final eventData = event.toJson();
      // Chuyển đổi DateTime thành Timestamp cho Firestore
      if (event.date != null) {
        eventData['date'] = Timestamp.fromDate(event.date!);
      }
      
      if (event.id != null) {
        // Update existing event
        await _firestore.collection('events').doc(event.id).update(eventData);
      } else {
        // Add new event
        await _firestore.collection('events').add(eventData);
      }
    } catch (e) {
      debugPrint('Lỗi khi lưu event: $e');
    }
  }

  // Lưu Task vào Firestore
  Future<void> _saveTask(Task task) async {
    // Kiểm tra disposed trước khi lưu
    if (_isDisposed || !mounted) {
      return;
    }
    
    try {
      final taskData = task.toJson();
      
      if (task.id != null) {
        // Update existing task
        await _firestore.collection('tasks').doc(task.id).update(taskData);
      } else {
        // Add new task
        await _firestore.collection('tasks').add(taskData);
      }
    } catch (e) {
      debugPrint('Lỗi khi lưu task: $e');
    }
  }

  // Xóa Event từ Firestore
  Future<void> _deleteEventFromFirestore(String eventId) async {
    // Kiểm tra disposed trước khi xóa
    if (_isDisposed || !mounted) {
      return;
    }
    
    try {
      await _firestore.collection('events').doc(eventId).delete();
    } catch (e) {
      debugPrint('Lỗi khi xóa event: $e');
    }
  }

  // Xóa Task từ Firestore
  Future<void> _deleteTaskFromFirestore(String taskId) async {
    // Kiểm tra disposed trước khi xóa
    if (_isDisposed || !mounted) {
      return;
    }
    
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
    } catch (e) {
      debugPrint('Lỗi khi xóa task: $e');
    }
  }

  // Hàm xóa Event
  void _deleteEvent(int index) {
    if (_isDisposed || !mounted || index < 0 || index >= _events.length) {
      return;
    }
    
    final event = _events[index];
    if (event.id != null) {
      _deleteEventFromFirestore(event.id!).then((_) {
        if (!_isDisposed && mounted) {
          _showNotification('Đã xóa', 'Sự kiện đã được xóa');
        }
      });
    } else {
      if (!_isDisposed && mounted) {
        _showNotification('Đã xóa', 'Sự kiện đã được xóa');
      }
    }
  }

  // Hàm xóa Task
  void _deleteTask(int index) {
    if (_isDisposed || !mounted || index < 0 || index >= _tasks.length) {
      return;
    }
    
    final task = _tasks[index];
    if (task.id != null) {
      _deleteTaskFromFirestore(task.id!).then((_) {
        if (!_isDisposed && mounted) {
          _showNotification('Đã xóa', 'Nhiệm vụ đã được xóa');
        }
      });
    } else {
      if (!_isDisposed && mounted) {
        _showNotification('Đã xóa', 'Nhiệm vụ đã được xóa');
      }
    }
  }

  // Dialog xác nhận xóa Event
  void _showDeleteEventDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa sự kiện "${_events[index].title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteEvent(index);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
  }

  // Dialog xác nhận xóa Task
  void _showDeleteTaskDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa nhiệm vụ "${_tasks[index].title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteTask(index);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
  }

  // Dialog hiển thị chi tiết Event
  void _showEventDetailsDialog(BuildContext context, Event event) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: event.color,
                child: Icon(event.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                const SizedBox(height: 12),
                // Ngày
                if (event.date != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Ngày:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 28.0),
                    child: Text(
                      _formatDate(event.date!),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Thời gian
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Thời gian:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28.0),
                  child: Text(
                    event.time,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                // Màu sắc
                Row(
                  children: [
                    const Icon(Icons.palette, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Màu sắc:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28.0),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: event.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: event.color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Đóng',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  // Hàm parse thời gian từ string (VD: "10:00 AM - 11:00 AM")
  TimeOfDay? _parseTimeFromString(String timeString) {
    try {
      // Tách phần đầu tiên (giờ bắt đầu)
      final parts = timeString.split(' - ');
      if (parts.isEmpty) return null;
      final startTimeStr = parts[0].trim();
      // Parse format "10:00 AM" hoặc "10:00AM"
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false).firstMatch(startTimeStr);
      if (timeMatch == null) return null;
      int hour = int.parse(timeMatch.group(1)!);
      int minute = int.parse(timeMatch.group(2)!);
      final period = timeMatch.group(3)!.toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  // Dialog chỉnh sửa Event
  void _showEditEventDialog(BuildContext context, int index) {
    final event = _events[index];
    final titleController = TextEditingController(text: event.title);
    DateTime? selectedDate = event.date ?? DateTime.now();
    // Parse thời gian từ string
    TimeOfDay? startTime = _parseTimeFromString(event.time);
    TimeOfDay? endTime;
    if (event.time.contains(' - ')) {
      final parts = event.time.split(' - ');
      if (parts.length > 1) {
        endTime = _parseTimeFromString(parts[1]);
      }
    }
    // Nếu không parse được, dùng giá trị mặc định
    startTime ??= TimeOfDay.now();
    endTime ??= TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute);
    IconData selectedIcon = event.icon;
    Color selectedColor = event.color;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PopScope(
              canPop: true,
              onPopInvoked: (didPop) {
                if (didPop) {
                  titleController.dispose();
                }
              },
              child: AlertDialog(
                title: const Text('Chỉnh sửa Sự kiện'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Tên sự kiện',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Chọn ngày'),
                        subtitle: Text(
                          selectedDate == null
                              ? 'Chưa chọn ngày'
                              : _formatDate(selectedDate!),
                        ),
                        onTap: () async {
                          final DateTime now = DateTime.now();
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? now,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 5),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('Giờ bắt đầu'),
                        subtitle: Text(
                          startTime == null
                              ? 'Chưa chọn giờ'
                              : _formatTimeOfDay(startTime!),
                        ),
                        onTap: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: startTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              startTime = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('Giờ kết thúc'),
                        subtitle: Text(
                          endTime == null
                              ? 'Chưa chọn giờ'
                              : _formatTimeOfDay(endTime!),
                        ),
                        onTap: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: endTime ?? startTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              endTime = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Icon:'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Icons.event,
                          Icons.group,
                          Icons.assignment,
                          Icons.school,
                          Icons.work,
                        ].map((icon) {
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedIcon = icon;
                              });
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: selectedIcon == icon
                                    ? Colors.blue.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedIcon == icon
                                      ? Colors.blue
                                      : Colors.grey.withOpacity(0.3),
                                  width: selectedIcon == icon ? 2 : 1,
                                ),
                              ),
                              child: Icon(
                                icon,
                                color: selectedIcon == icon
                                    ? Colors.blue
                                    : Colors.grey[700],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('Màu:'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.red, Colors.teal,
                        ].map((color) {
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor == color ? Colors.black : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập tên sự kiện'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (selectedDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng chọn ngày'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (startTime == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng chọn giờ bắt đầu'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (endTime == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng chọn giờ kết thúc'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      // Kiểm tra giờ kết thúc phải sau giờ bắt đầu
                      final startMinutes = startTime!.hour * 60 + startTime!.minute;
                      final endMinutes = endTime!.hour * 60 + endTime!.minute;
                      if (endMinutes <= startMinutes) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Giờ kết thúc phải sau giờ bắt đầu'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      // Lưu giá trị trước khi đóng dialog
                      final updatedEvent = Event(
                        id: event.id, // Giữ lại ID để update
                        title: title,
                        time: '${_formatTimeOfDay(startTime!)} - ${_formatTimeOfDay(endTime!)}',
                        date: selectedDate,
                        icon: selectedIcon,
                        color: selectedColor,
                      );
                      // Đóng dialog trước
                      Navigator.pop(dialogContext);
                      // Sử dụng SchedulerBinding để schedule callback an toàn (sau khi dialog đóng)
                      scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
                        if (!_isDisposed && mounted) {
                          _saveEvent(updatedEvent).then((_) {
                            if (!_isDisposed && mounted) {
                              _showNotification('Đã cập nhật', 'Sự kiện đã được chỉnh sửa');
                            }
                          });
                        }
                      });
                    },
                    child: const Text('Lưu'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Dialog chỉnh sửa Task
  void _showEditTaskDialog(BuildContext context, int index) {
    final task = _tasks[index];
    final titleController = TextEditingController(text: task.title);
    // Parse deadline để lấy ngày (bỏ phần "Hạn chót: ")
    final deadlineText = task.deadline.replaceFirst('Hạn chót: ', '');
    final deadlineController = TextEditingController(text: deadlineText);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: true,
          onPopInvoked: (didPop) {
            if (didPop) {
              titleController.dispose();
              deadlineController.dispose();
            }
          },
          child: AlertDialog(
            title: const Text('Chỉnh sửa Nhiệm vụ'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tên nhiệm vụ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: deadlineController,
                    decoration: const InputDecoration(
                      labelText: 'Hạn chót (VD: 25/05/2024)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  final deadline = deadlineController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập tên nhiệm vụ'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  if (deadline.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập hạn chót'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  // Lưu giá trị trước khi đóng dialog
                  final updatedTask = Task(
                    id: task.id, // Giữ lại ID để update
                    title: title,
                    deadline: 'Hạn chót: $deadline',
                  );
                  // Đóng dialog trước
                  Navigator.pop(dialogContext);
                  // Sử dụng SchedulerBinding để schedule callback an toàn (sau khi dialog đóng)
                  scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
                    if (!_isDisposed && mounted) {
                      _saveTask(updatedTask).then((_) {
                        if (!_isDisposed && mounted) {
                          _showNotification('Đã cập nhật', 'Nhiệm vụ đã được chỉnh sửa');
                        }
                      });
                    }
                  });
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Dialog hiển thị chi tiết Task
  void _showTaskDetailsDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.task_alt, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Hạn chót:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28.0),
                  child: Text(
                    task.deadline,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  // Mở dialog để chọn loại (Event hoặc Task)
  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Thêm mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event, color: Colors.blue),
                title: const Text('Thêm Sự kiện'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddEventDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.task_alt, color: Colors.green),
                title: const Text('Thêm Nhiệm vụ'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddTaskDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Hàm format TimeOfDay thành chuỗi
  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  // Hàm format DateTime thành chuỗi ngày
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // Dialog để thêm Event
  void _showAddEventDialog(BuildContext context) {
    final titleController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    IconData selectedIcon = Icons.event;
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PopScope(
              canPop: true,
              onPopInvoked: (didPop) {
                if (didPop) {
                  titleController.dispose();
                }
              },
              child: AlertDialog(
              title: const Text('Thêm Sự kiện'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tên sự kiện',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Chọn ngày'),
                      subtitle: Text(
                        selectedDate == null
                            ? 'Chưa chọn ngày'
                            : _formatDate(selectedDate!),
                      ),
                      onTap: () async {
                        final DateTime now = DateTime.now();
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 5),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Giờ bắt đầu'),
                      subtitle: Text(
                        startTime == null
                            ? 'Chưa chọn giờ'
                            : _formatTimeOfDay(startTime!),
                      ),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            startTime = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Giờ kết thúc'),
                      subtitle: Text(
                        endTime == null
                            ? 'Chưa chọn giờ'
                            : _formatTimeOfDay(endTime!),
                      ),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: startTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            endTime = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Icon:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Icons.event,
                        Icons.group,
                        Icons.assignment,
                        Icons.school,
                        Icons.work,
                      ].map((icon) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = icon;
                            });
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: selectedIcon == icon
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedIcon == icon
                                    ? Colors.blue
                                    : Colors.grey.withOpacity(0.3),
                                width: selectedIcon == icon ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: selectedIcon == icon
                                  ? Colors.blue
                                  : Colors.grey[700],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Màu:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.red, Colors.teal,
                      ].map((color) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == color ? Colors.black : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập tên sự kiện'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng chọn ngày'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (startTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng chọn giờ bắt đầu'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng chọn giờ kết thúc'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    // Kiểm tra giờ kết thúc phải sau giờ bắt đầu
                    final startMinutes = startTime!.hour * 60 + startTime!.minute;
                    final endMinutes = endTime!.hour * 60 + endTime!.minute;
                    if (endMinutes <= startMinutes) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Giờ kết thúc phải sau giờ bắt đầu'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final newEvent = Event(
                      title: title,
                      time: '${_formatTimeOfDay(startTime!)} - ${_formatTimeOfDay(endTime!)}',
                      date: selectedDate,
                      icon: selectedIcon,
                      color: selectedColor,
                    );
                    // Lưu title để hiển thị thông báo sau
                    final eventTitle = title;
                    // Đóng dialog trước (controller sẽ được dispose trong PopScope.onPopInvoked)
                    Navigator.pop(dialogContext);
                    // Sử dụng SchedulerBinding để schedule callback an toàn (sau khi dialog đóng)
                    scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
                      if (!_isDisposed && mounted) {
                        _saveEvent(newEvent).then((_) {
                          if (!_isDisposed && mounted) {
                            _showNotification('Sự kiện mới', 'Đã thêm: $eventTitle');
                          }
                        });
                      }
                    });
                  },
                  child: const Text('Thêm'),
                ),
              ],
            ),
            );
          },
        );
      },
    );
  }

  // Dialog để thêm Task
  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    DateTime? selectedDate;
    // Lưu context của widget chính
    final scaffoldContext = this.context;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PopScope(
              canPop: true,
              onPopInvoked: (didPop) {
                if (didPop) {
                  titleController.dispose();
                }
              },
              child: AlertDialog(
              title: const Text('Thêm Nhiệm vụ'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tên nhiệm vụ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Hạn chót'),
                      subtitle: Text(
                        selectedDate == null
                            ? 'Chưa chọn ngày'
                            : _formatDate(selectedDate!),
                      ),
                      onTap: () async {
                        final DateTime now = DateTime.now();
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 5),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập tên nhiệm vụ'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (selectedDate == null) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng chọn hạn chót'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final newTask = Task(
                      title: title,
                      deadline: 'Hạn chót: ${_formatDate(selectedDate!)}',
                    );
                    // Lưu title để hiển thị thông báo sau
                    final taskTitle = title;
                    // Đóng dialog trước (controller sẽ được dispose trong PopScope.onPopInvoked)
                    Navigator.pop(dialogContext);
                    // Sử dụng SchedulerBinding để schedule callback an toàn (sau khi dialog đóng)
                    scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
                      if (!_isDisposed && mounted) {
                        _saveTask(newTask).then((_) {
                          if (!_isDisposed && mounted) {
                            _showNotification('Nhiệm vụ mới', 'Đã thêm: $taskTitle');
                          }
                        });
                      }
                    });
                  },
                  child: const Text('Thêm'),
                ),
              ],
            ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng điều khiển'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Lịch trình hôm nay',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            _events.isEmpty
                ? const Center(child: Text('Không có sự kiện nào hôm nay.'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      return _buildTodayEvent(context, _events[index], index);
                    },
                  ),
            const SizedBox(height: 24.0),
            Text(
              'Nhiệm vụ sắp tới',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            _tasks.isEmpty
                ? const Center(child: Text('Không có nhiệm vụ nào sắp tới.'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      return _buildUpcomingTask(context, _tasks[index], index);
                    },
                  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        tooltip: 'Thêm mới',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodayEvent(BuildContext context, Event event, int index) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: event.color,
          child: Icon(event.icon, color: Colors.white, size: 24),
        ),
        title: Text(event.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(event.time),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.blue),
              onPressed: () => _showEventDetailsDialog(context, event),
              tooltip: 'Xem chi tiết',
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange),
              onPressed: () => _showEditEventDialog(context, index),
              tooltip: 'Chỉnh sửa',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteEventDialog(context, index),
              tooltip: 'Xóa sự kiện',
            ),
          ],
        ),
        onTap: () => _showEventDetailsDialog(context, event),
      ),
    );
  }

  Widget _buildUpcomingTask(BuildContext context, Task task, int index) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        leading: const Icon(Icons.task_alt, color: Colors.green, size: 28),
        title:
            Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(task.deadline),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.blue),
              onPressed: () => _showTaskDetailsDialog(context, task),
              tooltip: 'Xem chi tiết',
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange),
              onPressed: () => _showEditTaskDialog(context, index),
              tooltip: 'Chỉnh sửa',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteTaskDialog(context, index),
              tooltip: 'Xóa nhiệm vụ',
            ),
          ],
        ),
        onTap: () => _showTaskDetailsDialog(context, task),
      ),
    );
  }
}
