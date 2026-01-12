// Import các thư viện cần thiết
import 'dart:async'; // Bất đồng bộ và Stream
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore
import 'package:firebase_core/firebase_core.dart'; // Firebase Core
import 'package:flutter/material.dart'; // Flutter UI
import 'package:intl/intl.dart'; // Định dạng ngày tháng
import 'package:flutter_animate/flutter_animate.dart'; // Hiệu ứng animation
import 'package:shimmer/shimmer.dart'; // Hiệu ứng shimmer loading
import 'package:vibration/vibration.dart'; // Rung điện thoại
import 'package:flutter/services.dart'; // Dịch vụ hệ thống
import 'models.dart'; // Các model dữ liệu
import 'notification_service.dart'; // Dịch vụ thông báo

/// Màn hình chính - Quản lý nhiệm vụ
/// Bao gồm: CRUD tasks, tìm kiếm, lọc, tags, recurring tasks
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Kết nối Firebase Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Subscriptions để lắng nghe thay đổi từ Firebase
  StreamSubscription<QuerySnapshot>? _tasksSubscription;
  StreamSubscription<QuerySnapshot>? _projectsSubscription;
  
  // Danh sách dữ liệu
  final List<Task> _tasks = []; // Danh sách nhiệm vụ
  final List<Project> _projects = []; // Danh sách dự án
  
  // Trạng thái
  bool _isLoading = true; // Đang tải dữ liệu
  bool _isDisposed = false; // Widget đã bị hủy chưa
  
  // Tìm kiếm và lọc
  String _searchQuery = ''; // Từ khóa tìm kiếm
  String? _selectedProjectId; // Dự án đang chọn
  String? _selectedTag; // Tag đang chọn
  final TextEditingController _searchController = TextEditingController();
  bool _showCompletedTasks = false; // Hiển thị tasks đã hoàn thành

  /// Khởi tạo khi widget được tạo
  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Khởi tạo Firebase và thiết lập listeners
  Future<void> _init() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    _setupFirestoreListeners();
  }

  /// Dọn dẹp khi widget bị hủy
  @override
  void dispose() {
    _isDisposed = true;
    _tasksSubscription?.cancel(); // Hủy subscription tasks
    _projectsSubscription?.cancel(); // Hủy subscription projects
    _searchController.dispose();
    super.dispose();
  }

  /// Thiết lập listeners để lắng nghe thay đổi real-time từ Firebase
  void _setupFirestoreListeners() {
    // Lắng nghe thay đổi của tasks
    _tasksSubscription?.cancel();
    _tasksSubscription = _firestore.collection('tasks').snapshots().listen((
      snapshot,
    ) {
      if (_isDisposed) return; // Không cập nhật nếu widget đã bị hủy
      
      // Chuyển dữ liệu Firestore thành danh sách Task
      final newTasks = snapshot.docs
          .map((doc) => Task.fromFirestore(doc.data(), doc.id))
          .toList();

      // Sắp xếp: Priority trước, sau đó theo deadline
      newTasks.sort((a, b) {
        if (a.priority != b.priority)
          return b.priority.index.compareTo(a.priority.index);
        return a.deadlineDateTime.compareTo(b.deadlineDateTime);
      });

      if (mounted) {
        setState(() {
          _tasks.clear();
          _tasks.addAll(newTasks);
          _isLoading = false;
        });
      }
    });

    _projectsSubscription?.cancel();
    _projectsSubscription = _firestore
        .collection('projects')
        .snapshots()
        .listen((snapshot) {
          if (_isDisposed) return;
          final newProjects = snapshot.docs
              .map((doc) => Project.fromFirestore(doc.data(), doc.id))
              .toList();
          if (mounted) {
            setState(() {
              _projects.clear();
              _projects.addAll(newProjects);
            });
          }
        });
  }

  Future<void> _saveTask(Task task) async {
    final data = task.toJson();
    String docId;
    if (task.id != null) {
      docId = task.id!;
      await _firestore.collection('tasks').doc(docId).set(data);
    } else {
      final docRef = await _firestore.collection('tasks').add(data);
      docId = docRef.id;
    }

    final updatedTask = task.copyWith(id: docId);
    NotificationService.scheduleTaskNotification(updatedTask);
  }

  Future<void> _deleteTask(String id) async {
    await _firestore.collection('tasks').doc(id).delete();
    NotificationService.cancelNotification(id);
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
    );

    if (updated.isCompleted) {
      Vibration.hasVibrator().then((bool? hasVibrator) {
        if (hasVibrator == true) {
          Vibration.vibrate(duration: 100);
        }
      });
      // Nhận 10 xu khi hoàn thành nhiệm vụ
      await _firestore.collection('user_profile').doc('default_user').set({
        'coins': FieldValue.increment(10),
      }, SetOptions(merge: true));

      // Handle recurring tasks
      if (task.recurring != RecurringType.none) {
        await _createRecurringTask(task);
      }
    }

    await _saveTask(updated);
    if (updated.isCompleted && task.id != null) {
      NotificationService.cancelNotification(task.id!);
    }
  }

  Future<void> _createRecurringTask(Task task) async {
    DateTime nextDeadline;
    switch (task.recurring) {
      case RecurringType.daily:
        nextDeadline = task.deadlineDateTime.add(const Duration(days: 1));
        break;
      case RecurringType.weekly:
        nextDeadline = task.deadlineDateTime.add(const Duration(days: 7));
        break;
      case RecurringType.monthly:
        nextDeadline = DateTime(
          task.deadlineDateTime.year,
          task.deadlineDateTime.month + 1,
          task.deadlineDateTime.day,
          task.deadlineDateTime.hour,
          task.deadlineDateTime.minute,
        );
        break;
      default:
        return;
    }

    final newTask = Task(
      title: task.title,
      description: task.description,
      deadlineDateTime: nextDeadline,
      durationMinutes: task.durationMinutes,
      priority: task.priority,
      projectId: task.projectId,
      checklist: task.checklist.map((e) => ChecklistItem(title: e.title)).toList(),
      recurring: task.recurring,
      tags: task.tags,
    );

    await _saveTask(newTask);
  }

  Future<void> _showQuickAddDialog() async {
    final titleController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'QUICK ADD ⚡',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tên nhiệm vụ...',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _saveTask(
                Task(
                  title: value,
                  deadlineDateTime: DateTime.now().add(const Duration(hours: 1)),
                  priority: TaskPriority.medium,
                ),
              );
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                _saveTask(
                  Task(
                    title: titleController.text,
                    deadlineDateTime: DateTime.now().add(const Duration(hours: 1)),
                    priority: TaskPriority.medium,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('THÊM'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTaskDialog({Task? task}) async {
    final isEdit = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    DateTime selectedDate = task?.deadlineDateTime ?? DateTime.now();
    TaskPriority selectedPriority = task?.priority ?? TaskPriority.medium;
    String? projectId = task?.projectId;
    List<ChecklistItem> checklist = List.from(task?.checklist ?? []);
    RecurringType recurring = task?.recurring ?? RecurringType.none;
    List<String> tags = List.from(task?.tags ?? []);
    final tagController = TextEditingController();

    int selHour = selectedDate.hour;
    int selMin = selectedDate.minute;
    final hourController = FixedExtentScrollController(initialItem: selHour);
    final minController = FixedExtentScrollController(initialItem: selMin);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'NHIỆM VỤ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    if (isEdit)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          _deleteTask(task.id!);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Bạn cần làm gì?',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'DỰ ÁN',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._projects.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              p.name,
                              style: TextStyle(
                                color: projectId == p.id
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                            selected: projectId == p.id,
                            onSelected: (s) =>
                                setST(() => projectId = s ? p.id : null),
                            selectedColor: Color(p.colorValue),
                            backgroundColor: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.blueAccent,
                        ),
                        onPressed: _showAddProjectDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CHỌN NGÀY DEADLINE',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.calendar_month,
                        size: 16,
                        color: Colors.blueAccent,
                      ),
                      label: Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          builder: (context, child) =>
                              Theme(data: ThemeData.dark(), child: child!),
                        );
                        if (d != null) setST(() => selectedDate = d);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDigitalPicker(
                      hourController,
                      24,
                      (val) => setST(() => selHour = val),
                    ),
                    const Text(
                      ':',
                      style: TextStyle(color: Colors.white24, fontSize: 30),
                    ),
                    _buildDigitalPicker(
                      minController,
                      60,
                      (val) => setST(() => selMin = val),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'MỨC ĐỘ ƯU TIÊN',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: TaskPriority.values.map((p) {
                    final isSel = selectedPriority == p;
                    final color = p == TaskPriority.high
                        ? Colors.redAccent
                        : (p == TaskPriority.medium
                              ? Colors.orangeAccent
                              : Colors.greenAccent);
                    return ChoiceChip(
                      label: Text(
                        p.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: isSel ? Colors.black : color,
                        ),
                      ),
                      selected: isSel,
                      onSelected: (_) => setST(() => selectedPriority = p),
                      selectedColor: color,
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: color.withOpacity(0.3)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'LẶP LẠI',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: RecurringType.values.map((r) {
                      final labels = {
                        RecurringType.none: 'KHÔNG',
                        RecurringType.daily: 'HÀNG NGÀY',
                        RecurringType.weekly: 'HÀNG TUẦN',
                        RecurringType.monthly: 'HÀNG THÁNG',
                      };
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            labels[r]!,
                            style: TextStyle(
                              fontSize: 10,
                              color: recurring == r
                                  ? Colors.black
                                  : Colors.tealAccent,
                            ),
                          ),
                          selected: recurring == r,
                          onSelected: (_) => setST(() => recurring = r),
                          selectedColor: Colors.tealAccent,
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: Colors.tealAccent.withOpacity(0.3),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'TAGS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...tags.map(
                      (tag) => Chip(
                        label: Text(
                          '#$tag',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.purpleAccent.withOpacity(0.3),
                        deleteIcon: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white70,
                        ),
                        onDeleted: () => setST(() => tags.remove(tag)),
                      ),
                    ),
                    ActionChip(
                      label: const Icon(
                        Icons.add,
                        size: 14,
                        color: Colors.white70,
                      ),
                      backgroundColor: Colors.white.withOpacity(0.05),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1A1A),
                            title: const Text(
                              'THÊM TAG',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            content: TextField(
                              controller: tagController,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Tên tag...',
                                hintStyle:
                                    const TextStyle(color: Colors.white24),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (value) {
                                if (value.isNotEmpty && !tags.contains(value)) {
                                  setST(() => tags.add(value));
                                  tagController.clear();
                                  Navigator.pop(context);
                                }
                              },
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('HỦY'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purpleAccent,
                                ),
                                onPressed: () {
                                  if (tagController.text.isNotEmpty &&
                                      !tags.contains(tagController.text)) {
                                    setST(() => tags.add(tagController.text));
                                    tagController.clear();
                                    Navigator.pop(context);
                                  }
                                },
                                child: const Text('THÊM'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      final finalDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selHour,
                        selMin,
                      );
                      _saveTask(
                        Task(
                          id: task?.id,
                          title: titleController.text.isEmpty 
                              ? 'Nhiệm vụ mới' 
                              : titleController.text,
                          description: descController.text,
                          deadlineDateTime: finalDateTime,
                          priority: selectedPriority,
                          projectId: projectId,
                          checklist: checklist,
                          isCompleted: task?.isCompleted ?? false,
                          completedAt: task?.completedAt,
                          recurring: recurring,
                          tags: tags,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: Text(
                      isEdit ? 'CẬP NHẬT' : 'TẠO MỚI',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddProjectDialog() async {
    final controller = TextEditingController();
    Color selectedColor = Colors.blue;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'DỰ ÁN MỚI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Tên dự án',
                  hintStyle: TextStyle(color: Colors.white24),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                children:
                    [
                          Colors.blue,
                          Colors.red,
                          Colors.green,
                          Colors.orange,
                          Colors.purple,
                        ]
                        .map(
                          (c) => GestureDetector(
                            onTap: () => setST(() => selectedColor = c),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor == c
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('HỦY'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  _firestore
                      .collection('projects')
                      .add(
                        Project(
                          name: controller.text,
                          colorValue: selectedColor.value,
                        ).toJson(),
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('TẠO'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDigitalPicker(
    FixedExtentScrollController ctrl,
    int count,
    Function(int) onSelected,
  ) {
    return SizedBox(
      width: 70,
      height: 100,
      child: ListWheelScrollView.useDelegate(
        controller: ctrl,
        itemExtent: 50,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          onSelected(i);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) => Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              index.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTags = <String>{};
    for (var task in _tasks) {
      allTags.addAll(task.tags);
    }

    final filteredTasks = _tasks
        .where(
          (t) =>
              t.title.toLowerCase().contains(_searchQuery.toLowerCase()) &&
              (_selectedProjectId == null ||
                  t.projectId == _selectedProjectId) &&
              (_selectedTag == null || t.tags.contains(_selectedTag)) &&
              (_showCompletedTasks || !t.isCompleted),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F0F),
            flexibleSpace: const FlexibleSpaceBar(
              title: Text(
                'WORKSPACE APP',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  fontSize: 16,
                ),
              ),
              centerTitle: false,
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '🔍 Tìm kiếm nhiệm vụ...',
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white24,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white38,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(
                          _showCompletedTasks ? '✓ HOÀN THÀNH' : 'HOÀN THÀNH',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: _showCompletedTasks,
                        onSelected: (s) =>
                            setState(() => _showCompletedTasks = s),
                        selectedColor: Colors.greenAccent.withOpacity(0.3),
                        backgroundColor: const Color(0xFF1A1A1A),
                        checkmarkColor: Colors.greenAccent,
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text(
                          'ALL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: _selectedProjectId == null,
                        onSelected: (s) =>
                            setState(() => _selectedProjectId = null),
                        selectedColor: Colors.blueAccent,
                        backgroundColor: const Color(0xFF1A1A1A),
                      ),
                      const SizedBox(width: 8),
                      ..._projects.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              p.name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: _selectedProjectId == p.id,
                            onSelected: (s) => setState(
                              () => _selectedProjectId = s ? p.id : null,
                            ),
                            selectedColor: Color(p.colorValue),
                            backgroundColor: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      // Tags filter
                      if (allTags.isNotEmpty) ...[
                        Container(
                          width: 1,
                          height: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: Colors.white10,
                        ),
                        ChoiceChip(
                          label: const Text(
                            'ALL TAGS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: _selectedTag == null,
                          onSelected: (s) => setState(() => _selectedTag = null),
                          selectedColor: Colors.purpleAccent,
                          backgroundColor: const Color(0xFF1A1A1A),
                        ),
                        const SizedBox(width: 8),
                        ...allTags.map(
                          (tag) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                '#$tag',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: _selectedTag == tag,
                              onSelected: (s) => setState(
                                () => _selectedTag = s ? tag : null,
                              ),
                              selectedColor: Colors.purpleAccent,
                              backgroundColor: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            SliverFillRemaining(child: _buildShimmerLoading())
          else ...[
            if (filteredTasks.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.done_all,
                        size: 64,
                        color: Colors.white.withOpacity(0.05),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'TẤT CẢ ĐÃ XONG!',
                        style: TextStyle(
                          color: Colors.white24,
                          letterSpacing: 2,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildTaskItem(filteredTasks[index])
                      .animate()
                      .fadeIn(delay: (index * 50).ms)
                      .slideX(begin: 0.1, end: 0),
                  childCount: filteredTasks.length,
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'quick_add',
            onPressed: () => _showQuickAddDialog(),
            backgroundColor: Colors.blueAccent.withOpacity(0.8),
            child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
          ).animate().scale(delay: 600.ms),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'full_add',
            onPressed: () => _showTaskDialog(),
            backgroundColor: Colors.blueAccent,
            child: const Icon(Icons.add, color: Colors.white),
          ).animate().scale(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: const Color(0xFF1A1A1A),
        highlightColor: const Color(0xFF252525),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(Task t) {
    final isOverdue =
        t.deadlineDateTime.isBefore(DateTime.now()) && !t.isCompleted;
    final project = _projects.firstWhere(
      (p) => p.id == t.projectId,
      orElse: () => Project(name: '', colorValue: Colors.transparent.value),
    );

    int doneItems = t.checklist.where((e) => e.isDone).length;
    int totalItems = t.checklist.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isOverdue
              ? Colors.redAccent.withOpacity(0.2)
              : Colors.transparent,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        collapsedIconColor: Colors.white24,
        iconColor: Colors.blueAccent,
        leading: GestureDetector(
          onTap: () => _toggleTask(t),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: t.isCompleted ? Colors.blueAccent : Colors.white24,
                width: 2,
              ),
              color: t.isCompleted ? Colors.blueAccent : Colors.transparent,
            ),
            child: t.isCompleted
                ? const Icon(Icons.check, size: 14, color: Colors.black)
                : null,
          ),
        ),
        title: Text(
          t.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Row(
          children: [
            if (t.projectId != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(project.colorValue),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                project.name.toUpperCase(),
                style: TextStyle(
                  color: Color(project.colorValue).withOpacity(0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Icon(
              Icons.access_time,
              size: 12,
              color: isOverdue ? Colors.redAccent : Colors.white38,
            ),
            const SizedBox(width: 4),
            Text(
              DateFormat('dd/MM HH:mm').format(t.deadlineDateTime),
              style: TextStyle(
                color: isOverdue ? Colors.redAccent : Colors.white38,
                fontSize: 12,
              ),
            ),
            if (totalItems > 0) ...[
              const SizedBox(width: 12),
              Icon(
                Icons.checklist,
                size: 12,
                color: doneItems == totalItems
                    ? Colors.greenAccent
                    : Colors.white38,
              ),
              const SizedBox(width: 4),
              Text(
                '$doneItems/$totalItems',
                style: TextStyle(
                  color: doneItems == totalItems
                      ? Colors.greenAccent
                      : Colors.white38,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
        children: [
          if (t.checklist.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 56, right: 16, bottom: 16),
              child: Column(
                children: t.checklist
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: InkWell(
                          onTap: () {
                            item.isDone = !item.isDone;
                            _saveTask(t);
                          },
                          child: Row(
                            children: [
                              Icon(
                                item.isDone
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 14,
                                color: item.isDone
                                    ? Colors.blueAccent
                                    : Colors.white24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: item.isDone
                                      ? Colors.white24
                                      : Colors.white70,
                                  fontSize: 13,
                                  decoration: item.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showTaskDialog(task: t),
                  child: const Text(
                    'CHỈNH SỬA',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension ListAssignAll<T> on List<T> {
  void assignAll(Iterable<T> iterable) {
    clear();
    addAll(iterable);
  }
}
