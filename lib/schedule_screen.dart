// Import các thư viện cần thiết
import 'dart:async'; // Bất đồng bộ
import 'package:flutter/material.dart'; // Flutter UI
import 'package:table_calendar/table_calendar.dart'; // Widget lịch
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore
import 'package:flutter_animate/flutter_animate.dart'; // Hiệu ứng animation
import 'models.dart'; // Models

/// Màn hình lịch - Hiển thị nhiệm vụ theo ngày
/// Bao gồm: Calendar view, timeline view, quick edit
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // Cài đặt hiển thị của lịch
  CalendarFormat _calendarFormat = CalendarFormat.month; // Month/Week view
  DateTime _focusedDay = DateTime.now(); // Ngày đang focus
  DateTime? _selectedDay; // Ngày được chọn
  
  // Kết nối Firebase và subscriptions
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _tasksSubscription;
  StreamSubscription<QuerySnapshot>? _projectsSubscription;
  
  // Dữ liệu
  List<Task> _allTasks = []; // Tất cả tasks
  List<Project> _projects = []; // Tất cả projects
  
  // Trạng thái
  bool _isLoading = true; // Đang tải dữ liệu
  bool _colorByProject = false; // Màu theo project (false = theo priority)

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _setupFirestoreListeners();
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    _projectsSubscription?.cancel();
    super.dispose();
  }

  void _setupFirestoreListeners() {
    _tasksSubscription = _firestore.collection('tasks').snapshots().listen((
      snapshot,
    ) {
      final tasks = snapshot.docs
          .map((doc) => Task.fromFirestore(doc.data(), doc.id))
          .toList();
      if (mounted) {
        setState(() {
          _allTasks = tasks;
          _isLoading = false;
        });
      }
    });
    
    _projectsSubscription = _firestore.collection('projects').snapshots().listen((
      snapshot,
    ) {
      final projects = snapshot.docs
          .map((doc) => Project.fromFirestore(doc.data(), doc.id))
          .toList();
      if (mounted) {
        setState(() {
          _projects = projects;
        });
      }
    });
  }

  List<Task> _getTasksForDay(DateTime day) {
    return _allTasks
        .where((task) => isSameDay(task.deadlineDateTime, day))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tasksForSelectedDay = _getTasksForDay(_selectedDay ?? _focusedDay);
    tasksForSelectedDay.sort(
      (a, b) => a.deadlineDateTime.compareTo(b.deadlineDateTime),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: const Text(
          'LỊCH TRÌNH',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _colorByProject ? Icons.folder : Icons.priority_high,
              color: Colors.white70,
            ),
            tooltip: _colorByProject ? 'Color by Priority' : 'Color by Project',
            onPressed: () => setState(() => _colorByProject = !_colorByProject),
          ),
          IconButton(
            icon: Icon(
              _calendarFormat == CalendarFormat.month
                  ? Icons.calendar_view_week
                  : Icons.calendar_view_month,
              color: Colors.white70,
            ),
            onPressed: () => setState(
              () => _calendarFormat = _calendarFormat == CalendarFormat.month
                  ? CalendarFormat.week
                  : CalendarFormat.month,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) => setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            }),
            eventLoader: _getTasksForDay,
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            calendarStyle: CalendarStyle(
              defaultTextStyle: const TextStyle(color: Colors.white),
              weekendTextStyle: const TextStyle(color: Colors.white38),
              markerDecoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
            ),
          ).animate().fadeIn(),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  )
                : tasksForSelectedDay.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: tasksForSelectedDay.length,
                    itemBuilder: (context, index) =>
                        _buildTimelineItem(tasksForSelectedDay[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Task task, int index) {
    final hour = task.deadlineDateTime.hour.toString().padLeft(2, '0');
    final min = task.deadlineDateTime.minute.toString().padLeft(2, '0');
    final isOverdue =
        task.deadlineDateTime.isBefore(DateTime.now()) && !task.isCompleted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    Text(
                      hour,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Container(
                      height: 1,
                      width: 15,
                      color: Colors.white10,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                    Text(
                      min,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: Colors.white10,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _showQuickEditDialog(task),
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? Colors.blueAccent.withOpacity(0.05)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _getTaskColor(task).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: Colors.blueAccent.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${task.durationMinutes}m',
                          style: TextStyle(color: Colors.white24, fontSize: 10),
                        ),
                        const Spacer(),
                        if (isOverdue)
                          const Icon(
                            Icons.error_outline,
                            size: 14,
                            color: Colors.redAccent,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
  }

  Color _getTaskColor(Task task) {
    if (_colorByProject && task.projectId != null) {
      final project = _projects.firstWhere(
        (p) => p.id == task.projectId,
        orElse: () => Project(name: '', colorValue: Colors.blueAccent.value),
      );
      return Color(project.colorValue);
    }
    
    // Color by priority
    switch (task.priority) {
      case TaskPriority.high:
        return Colors.redAccent;
      case TaskPriority.medium:
        return Colors.orangeAccent;
      case TaskPriority.low:
        return Colors.greenAccent;
    }
  }

  Future<void> _showQuickEditDialog(Task task) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'QUICK ACTIONS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                task.isCompleted ? Icons.remove_done : Icons.check_circle,
                color: Colors.greenAccent,
              ),
              title: Text(
                task.isCompleted ? 'Mark as Incomplete' : 'Mark as Complete',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              onTap: () async {
                await _firestore.collection('tasks').doc(task.id).update({
                  'isCompleted': !task.isCompleted,
                  'completedAt': !task.isCompleted
                      ? FieldValue.serverTimestamp()
                      : null,
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event, color: Colors.blueAccent),
              title: const Text(
                'Reschedule to Tomorrow',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              onTap: () async {
                final tomorrow = DateTime.now().add(const Duration(days: 1));
                final newDeadline = DateTime(
                  tomorrow.year,
                  tomorrow.month,
                  tomorrow.day,
                  task.deadlineDateTime.hour,
                  task.deadlineDateTime.minute,
                );
                await _firestore.collection('tasks').doc(task.id).update({
                  'deadlineDateTime': Timestamp.fromDate(newDeadline),
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text(
                'Delete Task',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              onTap: () async {
                await _firestore.collection('tasks').doc(task.id).delete();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: Colors.white.withOpacity(0.05),
          ),
          const SizedBox(height: 16),
          const Text(
            'NO TASKS FOR THIS DAY',
            style: TextStyle(
              color: Colors.white24,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
