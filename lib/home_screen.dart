import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:flutter/scheduler.dart' as scheduler;

class Event {
  Event({
    required this.title,
    required this.time,
    required this.icon,
    required this.color,
    this.date,
    this.id,
  });

  final String? id;
  final String title;
  final String time; // ví dụ: "10:00 AM - 11:00 AM"
  final DateTime? date;
  final IconData icon;
  final Color color;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'time': time,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'icon': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'color': color.value,
    };
  }

  factory Event.fromFirestore(Map<String, dynamic> data, String id) {
    return Event(
      id: id,
      title: data['title'] as String? ?? '',
      time: data['time'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate(),
      icon: IconData(
        (data['icon'] as int?) ?? Icons.event.codePoint,
        fontFamily: data['iconFontFamily'] as String? ?? 'MaterialIcons',
        fontPackage: null,
        matchTextDirection: false,
      ),
      color: Color((data['color'] as int?) ?? Colors.blue.value),
    );
  }
}

class Task {
  Task({
    required this.title,
    required this.deadline,
    this.id,
  });

  final String? id;
  final String title;
  final String deadline; // ví dụ: "Hạn chót: 20/12/2025"

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'deadline': deadline,
    };
  }

  factory Task.fromFirestore(Map<String, dynamic> data, String id) {
    return Task(
      id: id,
      title: data['title'] as String? ?? '',
      deadline: data['deadline'] as String? ?? '',
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<QuerySnapshot>? _eventsSubscription;
  StreamSubscription<QuerySnapshot>? _tasksSubscription;
  Timer? _notificationTimer;
  bool _isDisposed = false;

  final List<Event> _events = [];
  final List<Task> _tasks = [];
  final Set<String> _notifiedEvents = {};
  final Set<String> _notifiedStartEvents = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Đảm bảo Firebase đã khởi tạo
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    await _initializeNotifications();
    _setupFirestoreListeners();
    _startNotificationChecker();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _eventsSubscription?.cancel();
    _tasksSubscription?.cancel();
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  void _startNotificationChecker() {
    _notificationTimer?.cancel();
    _notificationTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _checkUpcomingEvents());
    _checkUpcomingEvents(); // kiểm tra ngay lập tức
  }

  void _safeSetState(VoidCallback fn) {
    if (_isDisposed || !mounted) return;
    setState(fn);
  }

  void _setupFirestoreListeners() {
    if (_isDisposed || !mounted) return;

    _eventsSubscription?.cancel();
    _eventsSubscription =
        _firestore.collection('events').snapshots().listen((snapshot) {
      if (_isDisposed || !mounted) return;
      final newEvents = <Event>[];
      for (final doc in snapshot.docs) {
        try {
          newEvents.add(Event.fromFirestore(doc.data() as Map<String, dynamic>, doc.id));
        } catch (e) {
          debugPrint('Lỗi parse event: $e');
        }
      }
      _safeSetState(() {
        _events
          ..clear()
          ..addAll(newEvents);
      });
    });

    _tasksSubscription?.cancel();
    _tasksSubscription =
        _firestore.collection('tasks').snapshots().listen((snapshot) {
      if (_isDisposed || !mounted) return;
      final newTasks = <Task>[];
      for (final doc in snapshot.docs) {
        try {
          newTasks.add(Task.fromFirestore(doc.data() as Map<String, dynamic>, doc.id));
        } catch (e) {
          debugPrint('Lỗi parse task: $e');
        }
      }
      _safeSetState(() {
        _tasks
          ..clear()
          ..addAll(newTasks);
      });
    });
  }

  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'dattdd_channel',
      'Thời gian',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      await _notifications.show(notificationId, title, body, details);
      debugPrint('Đã gửi thông báo (ID: $notificationId)');
    } catch (e) {
      debugPrint('Lỗi khi gửi thông báo: $e');
    }
  }

  TimeOfDay? _parseTimeFromString(String timeString) {
    try {
      final parts = timeString.split(' - ');
      final startTimeStr = parts.first.trim();
      final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false)
          .firstMatch(startTimeStr);
      if (match == null) return null;

      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();

      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  void _checkUpcomingEvents() {
    final now = DateTime.now();

    for (final event in _events) {
      if (event.date == null) continue;

      final startTime = _parseTimeFromString(event.time);
      if (startTime == null) continue;

      final eventDateTime = DateTime(
        event.date!.year,
        event.date!.month,
        event.date!.day,
        startTime.hour,
        startTime.minute,
      );

      final difference = eventDateTime.difference(now);
      final minutesUntilEvent = difference.inMinutes;
      final secondsUntilEvent = difference.inSeconds;

      final key = '${event.title}_${eventDateTime.millisecondsSinceEpoch}';
      final startKey = 'start_$key';

      if (minutesUntilEvent > 0 &&
          minutesUntilEvent <= 15 &&
          !_notifiedEvents.contains(key)) {
        _showNotification('Sự kiện sắp tới', '${event.title} sẽ bắt đầu trong $minutesUntilEvent phút');
        _notifiedEvents.add(key);
      }

      if (minutesUntilEvent == 0 &&
          secondsUntilEvent >= 0 &&
          !_notifiedStartEvents.contains(startKey)) {
        _showNotification('Sự kiện đã bắt đầu',
            '${event.title} đã bắt đầu lúc ${_formatTimeOfDay(startTime)}');
        _notifiedStartEvents.add(startKey);
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt);
  }

  String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  Future<void> _saveEvent(Event event) async {
    final data = event.toJson();
    if (event.id != null) {
      await _firestore.collection('events').doc(event.id).set(data);
    } else {
      await _firestore.collection('events').add(data);
    }
  }

  Future<void> _saveTask(Task task) async {
    final data = task.toJson();
    if (task.id != null) {
      await _firestore.collection('tasks').doc(task.id).set(data);
    } else {
      await _firestore.collection('tasks').add(data);
    }
  }

  Future<void> _deleteEvent(String id) async {
    await _firestore.collection('events').doc(id).delete();
  }

  Future<void> _deleteTask(String id) async {
    await _firestore.collection('tasks').doc(id).delete();
  }

  Future<void> _showAddEventDialog() async {
    final titleController = TextEditingController();
    final timeController = TextEditingController(text: '10:00 AM - 11:00 AM');
    DateTime? selectedDate = DateTime.now();
    IconData selectedIcon = Icons.event;
    Color selectedColor = Colors.blue;

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Thêm sự kiện'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Tên sự kiện'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Thời gian (vd: 10:00 AM - 11:00 AM)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(selectedDate != null
                            ? _formatDate(selectedDate!)
                            : 'Chưa chọn ngày'),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: const Text('Chọn ngày'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                        Colors.red,
                      ].map((c) {
                        final isSelected = selectedColor.value == c.value;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.white,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Icons.event,
                        Icons.group,
                        Icons.work,
                        Icons.school,
                        Icons.sports_soccer,
                      ].map((icon) {
                        final isSelected = selectedIcon == icon;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedIcon = icon),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? Colors.blue.withOpacity(0.2) : null,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.grey,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Icon(icon),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty || selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập đủ thông tin'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final event = Event(
                  title: title,
                  time: timeController.text.trim(),
                  date: selectedDate,
                  icon: selectedIcon,
                  color: selectedColor,
                );
                _saveEvent(event);
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddTaskDialog() async {
    final titleController = TextEditingController();
    final deadlineController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Thêm nhiệm vụ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Tên nhiệm vụ'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: deadlineController,
                decoration: const InputDecoration(labelText: 'Hạn chót'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final deadline = deadlineController.text.trim();
                if (title.isEmpty || deadline.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập đủ thông tin'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                _saveTask(Task(title: title, deadline: deadline));
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteEvent(Event event) {
    if (event.id == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa sự kiện'),
        content: Text('Xóa "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteEvent(event.id!);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTask(Task task) {
    if (task.id == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nhiệm vụ'),
        content: Text('Xóa "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteTask(task.id!);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showEventDetailsDialog(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  void _showTaskDetailsDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.task_alt, color: Colors.blue, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 20, color: Colors.grey),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditEventDialog(Event event) async {
    if (event.id == null) return;
    
    final titleController = TextEditingController(text: event.title);
    final timeController = TextEditingController(text: event.time);
    DateTime? selectedDate = event.date;
    IconData selectedIcon = event.icon;
    Color selectedColor = event.color;

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chỉnh sửa sự kiện'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Tên sự kiện'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Thời gian (vd: 10:00 AM - 11:00 AM)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(selectedDate != null
                            ? _formatDate(selectedDate!)
                            : 'Chưa chọn ngày'),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: const Text('Chọn ngày'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                        Colors.red,
                      ].map((c) {
                        final isSelected = selectedColor.value == c.value;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.white,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Icons.event,
                        Icons.group,
                        Icons.work,
                        Icons.school,
                        Icons.sports_soccer,
                      ].map((icon) {
                        final isSelected = selectedIcon == icon;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedIcon = icon),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? Colors.blue.withOpacity(0.2) : null,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.grey,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Icon(icon),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty || selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập đủ thông tin'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final updatedEvent = Event(
                  id: event.id,
                  title: title,
                  time: timeController.text.trim(),
                  date: selectedDate,
                  icon: selectedIcon,
                  color: selectedColor,
                );
                _saveEvent(updatedEvent);
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditTaskDialog(Task task) async {
    if (task.id == null) return;
    
    final titleController = TextEditingController(text: task.title);
    final deadlineController = TextEditingController(text: task.deadline);

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chỉnh sửa nhiệm vụ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Tên nhiệm vụ'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: deadlineController,
                decoration: const InputDecoration(labelText: 'Hạn chót'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final deadline = deadlineController.text.trim();
                if (title.isEmpty || deadline.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập đủ thông tin'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final updatedTask = Task(
                  id: task.id,
                  title: title,
                  deadline: deadline,
                );
                _saveTask(updatedTask);
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEventTile(Event event) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: event.color,
          child: Icon(event.icon, color: Colors.white),
        ),
        title: Text(event.title),
        subtitle: Text(
          [
            if (event.date != null) _formatDate(event.date!),
            event.time,
          ].where((e) => e.isNotEmpty).join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.blue),
              onPressed: () => _showEventDetailsDialog(event),
              tooltip: 'Xem chi tiết',
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.green),
              onPressed: () => _showEditEventDialog(event),
              tooltip: 'Chỉnh sửa',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteEvent(event),
              tooltip: 'Xóa',
            ),
          ],
        ),
        onTap: () => _showEventDetailsDialog(event),
      ),
    );
  }

  Widget _buildTaskTile(Task task) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(task.title),
        subtitle: Text(task.deadline),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.blue),
              onPressed: () => _showTaskDetailsDialog(task),
              tooltip: 'Xem chi tiết',
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.green),
              onPressed: () => _showEditTaskDialog(task),
              tooltip: 'Chỉnh sửa',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteTask(task),
              tooltip: 'Xóa',
            ),
          ],
        ),
        onTap: () => _showTaskDetailsDialog(task),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _setupFirestoreListeners();
              _checkUpcomingEvents();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _setupFirestoreListeners();
          _checkUpcomingEvents();
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text(
              'Sự kiện',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_events.isEmpty)
              const Text('Chưa có sự kiện')
            else
              ..._events.map(_buildEventTile),
            const SizedBox(height: 16),
            const Text(
              'Nhiệm vụ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_tasks.isEmpty)
              const Text('Chưa có nhiệm vụ')
            else
              ..._tasks.map(_buildTaskTile),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _showAddEventDialog,
            heroTag: 'add_event',
            icon: const Icon(Icons.event),
            label: const Text('Sự kiện'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: _showAddTaskDialog,
            heroTag: 'add_task',
            icon: const Icon(Icons.task_alt),
            label: const Text('Nhiệm vụ'),
          ),
        ],
      ),
    );
  }
}
