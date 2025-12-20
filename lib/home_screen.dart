import 'dart:async';
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
  // Set để lưu các event đã gửi thông báo sắp tới (tránh trùng lặp)
  final Set<String> _notifiedEvents = {};
  // Set để lưu các event đã gửi thông báo đến giờ (tránh trùng lặp)
  final Set<String> _notifiedStartEvents = {};

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
    // Load dữ liệu và lắng nghe thay đổi từ Firestore
    // Đợi để đảm bảo Firebase đã sẵn sàng và widget đã mounted
    scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isDisposed && mounted) {
            _setupFirestoreListeners();
          }
        });
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
    }
  }

  // Bắt đầu kiểm tra thông báo định kỳ
  void _startNotificationChecker() {
    // Kiểm tra mỗi phút
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_isDisposed && mounted) {
        _checkUpcomingEvents();
      } else {
        timer.cancel();
      }
    });
    // Kiểm tra ngay lập tức
    if (!_isDisposed && mounted) {
      _checkUpcomingEvents();
    }
  }

  // Kiểm tra các sự kiện sắp tới và gửi thông báo
  void _checkUpcomingEvents() {
    // Kiểm tra disposed và mounted trước khi xử lý
    if (_isDisposed || !mounted) {
      return;
    }
    
    final now = DateTime.now();
    
    for (int i = 0; i < _events.length; i++) {
      final event = _events[i];
      if (event.date == null) continue;
      
      // Parse giờ bắt đầu từ event.time
      final startTime = _parseTimeFromString(event.time);
      if (startTime == null) continue;
      
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
      
      // Tạo key duy nhất cho event (để tránh thông báo trùng lặp)
      final eventKey = '${event.title}_${eventDateTime.millisecondsSinceEpoch}';
      final startEventKey = '${eventKey}_start';
      
      // Kiểm tra nếu còn dưới 15 phút và chưa gửi thông báo sắp tới
      if (minutesUntilEvent > 0 && 
          minutesUntilEvent <= 15 && 
          !_notifiedEvents.contains(eventKey)) {
        // Gửi thông báo sắp tới
        _showNotification(
          'Sự kiện sắp tới',
          '${event.title} sẽ bắt đầu trong $minutesUntilEvent phút',
        );
        // Đánh dấu đã gửi thông báo sắp tới
        _notifiedEvents.add(eventKey);
      }
      
      // Kiểm tra nếu đã đến giờ (trong vòng 1 phút đầu) và chưa gửi thông báo đến giờ
      if (minutesUntilEvent == 0 && 
          secondsUntilEvent >= 0 && 
          !_notifiedStartEvents.contains(startEventKey)) {
        // Gửi thông báo đến giờ
        _showNotification(
          'Sự kiện đã bắt đầu',
          '${event.title} đã bắt đầu lúc ${_formatTimeOfDay(startTime)}',
        );
        // Đánh dấu đã gửi thông báo đến giờ
        _notifiedStartEvents.add(startEventKey);
      }
      
      // Xóa các event đã qua khỏi set (dọn dẹp)
      if (minutesUntilEvent < -1) {
        _notifiedEvents.remove(eventKey);
        _notifiedStartEvents.remove(startEventKey);
      }
    }
  }

  // Gửi thông báo
  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'time_management_channel',
      'Time Management',
      channelDescription: 'Thông báo về thời khóa biểu',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationId++,
      title,
      body,
      details,
    );
  }

  // Thiết lập listeners cho Firestore để tự động cập nhật khi có thay đổi
  void _setupFirestoreListeners() {
    if (_isDisposed || !mounted) return;
    
    // Kiểm tra Firebase đã được khởi tạo chưa
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('Firebase chưa được khởi tạo, bỏ qua setup listeners');
        // Thử lại sau 1 giây
        Future.delayed(const Duration(seconds: 1), () {
          if (!_isDisposed && mounted) {
            _setupFirestoreListeners();
          }
        });
        return;
      }
    } catch (e) {
      debugPrint('Lỗi khi kiểm tra Firebase: $e');
      // Thử lại sau 1 giây nếu có lỗi
      Future.delayed(const Duration(seconds: 1), () {
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
          
          // Sử dụng SchedulerBinding thay vì WidgetsBinding để tránh tạo widget dependency
          // Kiểm tra lại mounted trước khi schedule callback
          if (!_isDisposed && mounted) {
            scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
              // Kiểm tra lại sau postFrameCallback
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
            });
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
          
          // Sử dụng SchedulerBinding thay vì WidgetsBinding để tránh tạo widget dependency
          // Kiểm tra lại mounted trước khi schedule callback
          if (!_isDisposed && mounted) {
            scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
              // Kiểm tra lại sau postFrameCallback
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
            });
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
    try {
      await _firestore.collection('events').doc(eventId).delete();
    } catch (e) {
      debugPrint('Lỗi khi xóa event: $e');
    }
  }

  // Xóa Task từ Firestore
  Future<void> _deleteTaskFromFirestore(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
    } catch (e) {
      debugPrint('Lỗi khi xóa task: $e');
    }
  }

  // Hàm xóa Event
  void _deleteEvent(int index) {
    final event = _events[index];
    if (event.id != null) {
      _deleteEventFromFirestore(event.id!);
    }
    _showNotification('Đã xóa', 'Sự kiện đã được xóa');
  }

  // Hàm xóa Task
  void _deleteTask(int index) {
    final task = _tasks[index];
    if (task.id != null) {
      _deleteTaskFromFirestore(task.id!);
    }
    _showNotification('Đã xóa', 'Nhiệm vụ đã được xóa');
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
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: event.color,
                child: Icon(event.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  event.title,
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: event.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 1),
                    ),
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
                          _saveEvent(updatedEvent);
                          _showNotification('Đã cập nhật', 'Sự kiện đã được chỉnh sửa');
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
                      _saveTask(updatedTask);
                      _showNotification('Đã cập nhật', 'Nhiệm vụ đã được chỉnh sửa');
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
                        _saveEvent(newEvent);
                        _showNotification('Sự kiện mới', 'Đã thêm: $eventTitle');
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
                        _saveTask(newTask);
                        _showNotification('Nhiệm vụ mới', 'Đã thêm: $taskTitle');
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
