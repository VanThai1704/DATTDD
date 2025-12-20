import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

// Model cho Event
class Event {
  final String title;
  final String time;
  final IconData icon;
  final Color color;

  Event({
    required this.title,
    required this.time,
    required this.icon,
    required this.color,
  });
}

// Model cho Task
class Task {
  final String title;
  final String deadline;

  Task({
    required this.title,
    required this.deadline,
  });
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

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
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

  // Danh sách events và tasks (lưu trong memory)
  final List<Event> _events = [
    Event(
      title: 'Họp nhóm',
      time: '10:00 AM - 11:00 AM',
      icon: Icons.group,
      color: Colors.orange,
    ),
    Event(
      title: 'Làm bài tập lớn',
      time: '2:00 PM - 4:00 PM',
      icon: Icons.assignment,
      color: Colors.blue,
    ),
  ];

  final List<Task> _tasks = [
    Task(title: 'Nộp báo cáo', deadline: 'Hạn chót: Ngày mai'),
    Task(title: 'Kiểm tra giữa kỳ', deadline: 'Hạn chót: 25/05/2024'),
  ];

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
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
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
                    Row(
                      children: [
                        const Text('Icon: '),
                        const SizedBox(width: 8),
                        DropdownButton<IconData>(
                          value: selectedIcon,
                          items: const [
                            DropdownMenuItem(value: Icons.event, child: Icon(Icons.event)),
                            DropdownMenuItem(value: Icons.group, child: Icon(Icons.group)),
                            DropdownMenuItem(value: Icons.assignment, child: Icon(Icons.assignment)),
                            DropdownMenuItem(value: Icons.school, child: Icon(Icons.school)),
                            DropdownMenuItem(value: Icons.work, child: Icon(Icons.work)),
                          ],
                          onChanged: (IconData? value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedIcon = value;
                              });
                            }
                          },
                        ),
                      ],
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text;
                    if (title.isNotEmpty && startTime != null && endTime != null) {
                      final newEvent = Event(
                        title: title,
                        time: '${_formatTimeOfDay(startTime!)} - ${_formatTimeOfDay(endTime!)}',
                        icon: selectedIcon,
                        color: selectedColor,
                      );
                      setState(() {
                        _events.add(newEvent);
                      });
                      _showNotification('Sự kiện mới', 'Đã thêm: $title');
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Thêm'),
                ),
              ],
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text;
                    if (title.isNotEmpty && selectedDate != null) {
                      final newTask = Task(
                        title: title,
                        deadline: 'Hạn chót: ${_formatDate(selectedDate!)}',
                      );
                      setState(() {
                        _tasks.add(newTask);
                      });
                      _showNotification('Nhiệm vụ mới', 'Đã thêm: $title');
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Thêm'),
                ),
              ],
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
                      return _buildTodayEvent(context, _events[index]);
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
                      return _buildUpcomingTask(context, _tasks[index]);
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

  Widget _buildTodayEvent(BuildContext context, Event event) {
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
      ),
    );
  }

  Widget _buildUpcomingTask(BuildContext context, Task task) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        leading: const Icon(Icons.task_alt, color: Colors.green, size: 28),
        title:
            Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(task.deadline),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // Xử lý khi nhấn vào task
        },
      ),
    );
  }
}
