// Import các thư viện cần thiết
import 'dart:async'; // Xử lý bất đồng bộ và Timer
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore database
import 'package:flutter/material.dart'; // Flutter UI framework
import 'package:flutter/services.dart'; // Dịch vụ hệ thống (haptic feedback)
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Thông báo local
import 'package:vibration/vibration.dart'; // Rung điện thoại
import 'package:flutter_animate/flutter_animate.dart'; // Hiệu ứng animation
import 'package:audioplayers/audioplayers.dart'; // Phát nhạc và âm thanh
import 'models.dart'; // Các model dữ liệu
import 'package:intl/intl.dart'; // Định dạng ngày tháng

/// Màn hình Focus Session - nơi người dùng tập trung làm việc
/// Bao gồm timer, âm thanh, theo dõi tiến độ và nhiều tính năng khác
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  // Controllers cho wheel picker chọn giờ và phút
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minController;
  
  // Audio player để phát nhạc nền và âm báo
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Thời gian làm việc đã chọn
  int _workHours = 0; // Số giờ
  int _workMinutes = 0; // Số phút
  int _remainingSeconds = 0; // Số giây còn lại trong countdown

  // Trạng thái của timer và chế độ
  bool _isRunning = false; // Timer có đang chạy không
  bool _isWorkMode = true; // Chế độ làm việc (true) hay nghỉ (false)
  bool _isDeepFocus = false; // Chế độ tập trung sâu (cảnh báo khi rời app)

  // Âm thanh báo thức khi hết giờ
  String _selectedAlarm = 'Default';
  final List<String> _alarms = [
    'Default',
    'Piano',
    'Zen',
    'Nature',
    'Chimes',
    'Bell',
  ];
  
  // Tiếng ồn trắng (white noise) phát trong khi làm việc
  final List<String> _whitenoise = [
    'None', // Không có
    'Rain', // Tiếng mưa
    'Ocean', // Tiếng sóng biển
    'Forest', // Tiếng rừng
    'Fireplace', // Tiếng lò sưởi
    'Cafe', // Tiếng quán cafe
  ];
  String _selectedWhiteNoise = 'None';

  // Thống kê và tiến độ
  int _totalFocusMinutes = 0; // Tổng số phút tập trung hôm nay
  int _currentStreak = 0; // Chuỗi ngày liên tục tập trung
  Task? _selectedTask; // Nhiệm vụ đang làm (nếu có)
  Project? _selectedProject; // Dự án đang làm (nếu có)
  List<Project> _projects = []; // Danh sách tất cả dự án

  // Kết nối Firebase và thông báo
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Khởi tạo khi màn hình được tạo
  @override
  void initState() {
    super.initState();
    // Khởi tạo controllers cho wheel picker
    _hourController = FixedExtentScrollController(initialItem: 0);
    _minController = FixedExtentScrollController(initialItem: 0);
    
    // Theo dõi lifecycle của app (để phát hiện khi user rời app trong Deep Focus)
    WidgetsBinding.instance.addObserver(this);
    
    // Khởi tạo hệ thống thông báo
    _initializeNotifications();
    
    // Tải dữ liệu từ Firebase
    _loadData();
  }

  /// Dọn dẹp resources khi màn hình bị hủy
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hourController.dispose();
    _minController.dispose();
    _timer?.cancel(); // Hủy timer nếu đang chạy
    _audioPlayer.dispose(); // Dừng và giải phóng audio player
    super.dispose();
  }

  /// Tải tất cả dữ liệu cần thiết
  Future<void> _loadData() async {
    await _loadTodayStats(); // Tải thống kê hôm nay
    await _loadProjects(); // Tải danh sách dự án
  }

  /// Tải danh sách các dự án từ Firebase
  Future<void> _loadProjects() async {
    final snapshot = await _firestore.collection('projects').get();
    if (mounted) {
      setState(() {
        _projects = snapshot.docs
            .map((doc) => Project.fromFirestore(doc.data(), doc.id))
            .toList();
      });
    }
  }

  /// Tải thống kê hôm nay và tính streak
  Future<void> _loadTodayStats() async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    // Lấy tất cả các phiên tập trung
    final focusSnapshot = await _firestore.collection('focus_sessions').get();
    int total = 0; // Tổng phút tập trung hôm nay
    Set<String> activeDays = {}; // Set các ngày đã có phiên tập trung

    // Duyệt qua tất cả các phiên
    for (var doc in focusSnapshot.docs) {
      final data = doc.data();
      // Tính tổng thời gian hôm nay
      if (data['date'] == todayStr) total += (data['duration'] as int? ?? 0);
      // Lưu ngày có hoạt động
      if (data['date'] != null) activeDays.add(data['date']);
    }

    // Tính streak (chuỗi ngày liên tục)
    int streak = 0;
    DateTime checkDate = now;
    // Nếu hôm nay chưa có hoạt động, bắt đầu từ hôm qua
    if (!activeDays.contains(todayStr))
      checkDate = now.subtract(const Duration(days: 1));
    // Đếm ngược từng ngày cho đến khi gặp ngày không có hoạt động
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

  /// Theo dõi trạng thái lifecycle của app
  /// Dùng để phát hiện khi user rời app trong chế độ Deep Focus
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nếu đang chạy timer, ở chế độ làm việc và bật Deep Focus
    if (_isRunning && _isWorkMode && _isDeepFocus) {
      // Khi app bị pause hoặc inactive (user rời app)
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        _handleDeepFocusViolation(); // Cảnh báo vi phạm
      }
    }
  }

  /// Xử lý khi user vi phạm Deep Focus (rời app)
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

  Timer? _timer; // Timer đếm ngược
  
  /// Bắt đầu đếm ngược
  void _startTimer() {
    // Kiểm tra đã chọn thời gian chưa
    if (_remainingSeconds <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn thời gian!')));
      return;
    }
    if (_timer != null) return; // Tránh tạo nhiều timer
    setState(() => _isRunning = true);
    if (_isWorkMode) _playMusic(); // Phát nhạc nếu đang làm việc

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

  /// Xử lý khi timer hoàn thành (hết giờ)
  void _completeTimer() {
    _timer?.cancel(); // Hủy timer
    _timer = null;
    _isRunning = false;
    _audioPlayer.stop(); // Dừng nhạc nền
    _playAlarm(); // Phát âm báo

    if (_isWorkMode) {
      // Nếu là chế độ làm việc
      int duration = (_workHours * 60) + _workMinutes;
      _saveSession(duration); // Lưu phiên vào Firebase
      Vibration.vibrate(pattern: [0, 300, 200, 300, 200, 500]); // Rung
      _showCompletionDialog(duration); // Hiện dialog hoàn thành
    } else {
      // Nếu là chế độ nghỉ
      _showTimeUpDialog(); // Hiện dialog hết giờ nghỉ
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
      'projectId': _selectedProject?.id,
      'projectName': _selectedProject?.name,
      'alarmSound': _selectedAlarm,
      'whiteNoise': _selectedWhiteNoise,
      'deepFocus': _isDeepFocus,
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

  /// Tạm dừng timer
  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() => _isRunning = false);
    _audioPlayer.stop(); // Dừng nhạc
    _showPauseReasonDialog(); // Hỏi lý do tạm dừng
  }

  void _showPauseReasonDialog() {
    final reasons = [
      'Cần giải lao',
      'Bị gián đoạn',
      'Cần uống nước',
      'Mệt mỏi',
      'Khác',
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'LÝ DO TẠM DỪNG?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map(
                (reason) => ListTile(
                  title: Text(
                    reason,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  onTap: () {
                    debugPrint('Paused: $reason');
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  /// Reset timer về 0
  void _resetTimer() {
    _pauseTimer(); // Dừng timer trước
    setState(() {
      _workHours = 0;
      _workMinutes = 0;
      _remainingSeconds = 0;
      // Reset wheel picker về 0
      _hourController.jumpToItem(0);
      _minController.jumpToItem(0);
    });
  }

  /// Chuyển đổi giữa chế độ làm việc và nghỉ
  void _switchMode() {
    _isWorkMode = !_isWorkMode; // Toggle mode
    _pauseTimer(); // Dừng timer hiện tại
    setState(() {
      // Set thời gian mới: work time hoặc 5 phút nghỉ
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

  /// Build giao diện chính
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), // Màu nền tối
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(), // Tiêu đề "FOCUS SESSION" / "REST TIME"
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    _buildStreakCounter(), // Hiển thị streak
                    const SizedBox(height: 30),
                    if (!_isRunning) _buildPresetButtons(), // Nút preset thời gian
                    const SizedBox(height: 20),
                    _buildClockDisplay(), // Đồng hồ đếm ngược
                    const SizedBox(height: 30),
                    _buildAlarmSelector(), // Chọn alarm và white noise
                    const SizedBox(height: 20),
                    _buildProjectSelector(), // Chọn dự án
                    const SizedBox(height: 20),
                    _buildDeepFocusToggle(), // Toggle Deep Focus
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildActionButtons(), // Các nút Play/Pause/Reset/Skip
            const SizedBox(height: 20),
            _buildBottomStats(), // Thanh progress hôm nay
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Build header (tiêu đề màn hình)
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

  /// Build các nút preset thời gian nhanh
  Widget _buildPresetButtons() {
    // Danh sách preset khác nhau cho chế độ làm việc và nghỉ
    final presets = _isWorkMode
        ? [
            // Chế độ làm việc: 25, 45, 90 phút
            {'label': '25m', 'minutes': 25, 'icon': Icons.bolt},
            {'label': '45m', 'minutes': 45, 'icon': Icons.wb_sunny},
            {'label': '90m', 'minutes': 90, 'icon': Icons.rocket_launch},
          ]
        : [
            // Chế độ nghỉ: 5, 15 phút
            {'label': '5m', 'minutes': 5, 'icon': Icons.coffee},
            {'label': '15m', 'minutes': 15, 'icon': Icons.local_cafe},
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Text(
            _isWorkMode ? 'PRESETS' : 'BREAK PRESETS',
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: presets.map((preset) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    foregroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(
                        color: Colors.blueAccent.withOpacity(0.3),
                      ),
                    ),
                  ),
                  icon: Icon(preset['icon'] as IconData, size: 16),
                  label: Text(
                    preset['label'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () {
                    final minutes = preset['minutes'] as int;
                    setState(() {
                      if (_isWorkMode) {
                        _workHours = minutes ~/ 60;
                        _workMinutes = minutes % 60;
                        _hourController.jumpToItem(_workHours);
                        _minController.jumpToItem(_workMinutes);
                      }
                      _remainingSeconds = minutes * 60;
                    });
                    HapticFeedback.mediumImpact();
                  },
                ),
              );
            }).toList(),
          ),
        ],
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

  /// Build phần hiển thị đồng hồ (countdown hoặc wheel picker)
  Widget _buildClockDisplay() {
    // Hiển thị countdown nếu đang chạy HOẶC đã pause (còn thời gian)
    if (_isRunning || _remainingSeconds > 0) {
      // Tính giờ:phút:giây từ tổng số giây còn lại
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
      // Chỉ hiển thị wheel picker khi chưa set thời gian
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
      child: Column(
        children: [
          Row(
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
                  return DropdownMenuItem<String>(
                      value: value, child: Text(value));
                }).toList(),
                onChanged: (v) => setState(() => _selectedAlarm = v!),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'WHITE NOISE',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              DropdownButton<String>(
                value: _selectedWhiteNoise,
                dropdownColor: const Color(0xFF1A1A1A),
                underline: const SizedBox(),
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                items: _whitenoise.map((String value) {
                  return DropdownMenuItem<String>(
                      value: value, child: Text(value));
                }).toList(),
                onChanged: (v) => setState(() => _selectedWhiteNoise = v!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSelector() {
    if (_projects.isEmpty) return const SizedBox();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DỰ ÁN',
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
              children: [
                ChoiceChip(
                  label: const Text(
                    'NONE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  selected: _selectedProject == null,
                  onSelected: (s) => setState(() => _selectedProject = null),
                  selectedColor: Colors.grey,
                  backgroundColor: Colors.white.withOpacity(0.05),
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
                      selected: _selectedProject?.id == p.id,
                      onSelected: (s) =>
                          setState(() => _selectedProject = s ? p : null),
                      selectedColor: Color(p.colorValue),
                      backgroundColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
              ],
            ),
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
