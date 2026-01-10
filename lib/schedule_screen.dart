import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'models.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _tasksSubscription;
  List<Task> _allTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _setupFirestoreListeners();
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
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
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: task.isCompleted
                    ? Colors.blueAccent.withOpacity(0.05)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isOverdue
                      ? Colors.redAccent.withOpacity(0.3)
                      : Colors.white.withOpacity(0.05),
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
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
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
