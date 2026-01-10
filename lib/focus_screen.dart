import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _workHours = 0;
  int _workMinutes = 0;
  int _remainingSeconds = 0;

  bool _isRunning = false;
  bool _isWorkMode = true;
  bool _isDeepFocus = false;

  String _selectedAlarm = 'Default';
  final List<String> _alarms = ['Default', 'Piano', 'Zen', 'Nature'];

  int _totalFocusMinutes = 0;
  int _currentStreak = 0;
  Task? _selectedTask;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _hourController = FixedExtentScrollController(initialItem: 0);
    _minController = FixedExtentScrollController(initialItem: 0);
    WidgetsBinding.instance.addObserver(this);
    _initializeNotifications();
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hourController.dispose();
    _minController.dispose();
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadTodayStats();
  }

  Future<void> _loadTodayStats() async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final focusSnapshot = await _firestore.collection('focus_sessions').get();
    int total = 0;
    Set<String> activeDays = {};

    for (var doc in focusSnapshot.docs) {
      final data = doc.data();
      if (data['date'] == todayStr) total += (data['duration'] as int? ?? 0);
      if (data['date'] != null) activeDays.add(data['date']);
    }

    int streak = 0;
    DateTime checkDate = now;
    if (!activeDays.contains(todayStr))
      checkDate = now.subtract(const Duration(days: 1));
    while (activeDays.contains(DateFormat('yyyy-MM-dd').format(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    if (mounted) {
      setState(() {
        _totalFocusMinutes = total;
        _currentStreak = streak;
      });
    }
  }

  Future<void> _initializeNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isRunning && _isWorkMode && _isDeepFocus) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        _handleDeepFocusViolation();
      }
    }
  }

  void _handleDeepFocusViolation() async {
    Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'focus_violation',
        'Deep Focus',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
    await _notifications.show(
      888,
      '⚠️ VI PHẠM TẬP TRUNG!',
      'Quay lại app ngay để tiếp tục phiên làm việc.',
      details,
    );
  }

  Timer? _timer;
  void _startTimer() {
    if (_remainingSeconds <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn thời gian!')));
      return;
    }
    if (_timer != null) return;
    setState(() => _isRunning = true);
    if (_isWorkMode) _playMusic();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _completeTimer();
          }
        });
      }
    });
  }

  void _playMusic() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(
        UrlSource(
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        ),
      );
    } catch (e) {
      debugPrint('Lỗi nhạc: $e');
    }
  }

  void _completeTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _audioPlayer.stop();
    _playAlarm();

    if (_isWorkMode) {
      int duration = (_workHours * 60) + _workMinutes;
      _saveSession(duration);
      Vibration.vibrate(pattern: [0, 300, 200, 300, 200, 500]);
      _showCompletionDialog(duration);
    } else {
      _showTimeUpDialog();
    }
  }

  void _playAlarm() async {
    // Logic phát âm báo kết thúc phiên
    debugPrint('Phát âm báo: $_selectedAlarm');
  }

  Future<void> _saveSession(int durationMinutes) async {
    final now = DateTime.now();
    await _firestore.collection('focus_sessions').add({
      'createdAt': FieldValue.serverTimestamp(),
      'duration': durationMinutes,
      'date': DateFormat('yyyy-MM-dd').format(now),
      'taskId': _selectedTask?.id,
      'taskTitle': _selectedTask?.title,
    });
    _loadTodayStats();
  }

  void _showCompletionDialog(int duration) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'TUYỆT VỜI 🏆',
          style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2),
        ),
        content: Text(
          'Bạn đã tập trung được $duration phút. Bạn đã hoàn thành nhiệm vụ này chưa?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _switchMode();
            },
            child: const Text('CHƯA XONG'),
          ),
          if (_selectedTask != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                await _firestore
                    .collection('tasks')
                    .doc(_selectedTask!.id)
                    .update({
                      'isCompleted': true,
                      'completedAt': FieldValue.serverTimestamp(),
                    });
                await _firestore
                    .collection('user_profile')
                    .doc('default_user')
                    .update({'coins': FieldValue.increment(10)});
                Navigator.pop(context);
                _switchMode();
                _loadData();
              },
              child: const Text('XONG & +10 🪙'),
            ),
        ],
      ),
    );
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() => _isRunning = false);
    _audioPlayer.stop();
  }

  void _resetTimer() {
    _pauseTimer();
    setState(() {
      _workHours = 0;
      _workMinutes = 0;
      _remainingSeconds = 0;
      _hourController.jumpToItem(0);
      _minController.jumpToItem(0);
    });
  }

  void _switchMode() {
    _isWorkMode = !_isWorkMode;
    _pauseTimer();
    setState(() {
      _remainingSeconds =
          (_isWorkMode ? (_workHours * 60 + _workMinutes) : 5) * 60;
    });
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'HẾT GIỜ NGHỈ!',
          style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2),
        ),
        content: const Text(
          'Sẵn sàng quay lại làm việc chưa?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _switchMode();
            },
            child: const Text('BẮT ĐẦU'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    _buildStreakCounter(),
                    const SizedBox(height: 30),
                    _buildClockDisplay(),
                    const SizedBox(height: 30),
                    _buildAlarmSelector(),
                    const SizedBox(height: 20),
                    _buildDeepFocusToggle(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildActionButtons(),
            const SizedBox(height: 20),
            _buildBottomStats(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        _isWorkMode ? 'FOCUS SESSION' : 'REST TIME',
        style: TextStyle(
          color: _isWorkMode ? Colors.redAccent : Colors.tealAccent,
          letterSpacing: 4,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStreakCounter() {
    return Column(
      children: [
        const Icon(
          Icons.local_fire_department,
          color: Colors.orange,
          size: 40,
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
        const SizedBox(height: 8),
        Text(
          '$_currentStreak DAY STREAK',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildClockDisplay() {
    if (_isRunning) {
      int totalSeconds = _remainingSeconds;
      int hours = totalSeconds ~/ 3600;
      int minutes = (totalSeconds % 3600) ~/ 60;
      int seconds = totalSeconds % 60;

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTimeTile(hours.toString().padLeft(2, '0'), active: true),
          const Text(
            ':',
            style: TextStyle(color: Colors.white10, fontSize: 30),
          ),
          _buildTimeTile(minutes.toString().padLeft(2, '0'), active: true),
          const Text(
            ':',
            style: TextStyle(color: Colors.white10, fontSize: 30),
          ),
          _buildTimeTile(seconds.toString().padLeft(2, '0'), active: true),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildWheelPicker(
            _hourController,
            24,
            'H',
            (v) => setState(() {
              _workHours = v;
              _remainingSeconds = (_workHours * 3600 + _workMinutes * 60);
            }),
          ),
          const SizedBox(width: 10),
          _buildWheelPicker(
            _minController,
            60,
            'M',
            (v) => setState(() {
              _workMinutes = v;
              _remainingSeconds = (_workHours * 3600 + _workMinutes * 60);
            }),
          ),
        ],
      );
    }
  }

  Widget _buildWheelPicker(
    FixedExtentScrollController ctrl,
    int count,
    String label,
    Function(int) onSelected,
  ) {
    return SizedBox(
      width: 100,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListWheelScrollView.useDelegate(
            controller: ctrl,
            itemExtent: 80,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) {
              HapticFeedback.lightImpact();
              onSelected(index);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, index) => _buildTimeTile(
                index.toString().padLeft(2, '0'),
                active: true,
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 40,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTile(String value, {bool active = false}) {
    return Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? Colors.white.withOpacity(0.1) : Colors.transparent,
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: active ? Colors.white : Colors.white10,
          fontSize: 40,
          fontWeight: FontWeight.w200,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildAlarmSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ALARM SOUND',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          DropdownButton<String>(
            value: _selectedAlarm,
            dropdownColor: const Color(0xFF1A1A1A),
            underline: const SizedBox(),
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            items: _alarms.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (v) => setState(() => _selectedAlarm = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildDeepFocusToggle() {
    return GestureDetector(
      onTap: () {
        setState(() => _isDeepFocus = !_isDeepFocus);
        HapticFeedback.mediumImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _isDeepFocus
              ? Colors.redAccent.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isDeepFocus ? Colors.redAccent : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_clock,
              size: 14,
              color: _isDeepFocus ? Colors.redAccent : Colors.white38,
            ),
            const SizedBox(width: 8),
            Text(
              'DEEP FOCUS MODE',
              style: TextStyle(
                color: _isDeepFocus ? Colors.redAccent : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircleAction(Icons.refresh, _resetTimer),
        const SizedBox(width: 40),
        GestureDetector(
          onTap: _isRunning ? _pauseTimer : _startTimer,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 50,
            ),
          ),
        ),
        const SizedBox(width: 40),
        _buildCircleAction(Icons.skip_next_rounded, _switchMode),
      ],
    );
  }

  Widget _buildCircleAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildBottomStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TODAY FOCUS',
                style: TextStyle(
                  color: Colors.white10,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${_totalFocusMinutes}m / 120m',
                style: const TextStyle(color: Colors.white30, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_totalFocusMinutes / 120).clamp(0, 1),
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
