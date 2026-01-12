// Import các thư viện UI và services
import 'package:convex_bottom_bar/convex_bottom_bar.dart'; // Thanh điều hướng dưới có hiệu ứng
import 'package:datbdd/focus_screen.dart'; // Màn hình tập trung
import 'package:datbdd/home_screen.dart'; // Màn hình chính - quản lý nhiệm vụ
import 'package:datbdd/schedule_screen.dart'; // Màn hình lịch
import 'package:datbdd/stats_screen.dart'; // Màn hình thống kê
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Khởi tạo Firebase
import 'notification_service.dart'; // Dịch vụ thông báo
import 'package:permission_handler/permission_handler.dart'; // Quản lý quyền
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore
import 'package:badges/badges.dart' as badges; // Hiển thị số badge

/// Hàm main - điểm khởi đầu của ứng dụng
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Đảm bảo Flutter đã khởi tạo
  try {
    await Firebase.initializeApp(); // Khởi tạo Firebase
    await NotificationService.init(); // Khởi tạo dịch vụ thông báo
    await _requestPermissions(); // Yêu cầu các quyền cần thiết
  } catch (e) {
    debugPrint('Lỗi khởi tạo: $e');
  }
  runApp(const MyApp()); // Chạy ứng dụng
}

/// Yêu cầu các quyền cần thiết từ người dùng
Future<void> _requestPermissions() async {
  // Yêu cầu quyền gửi thông báo
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // Yêu cầu quyền hẹn giờ chính xác (Android 12+)
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }
}

/// Widget gốc của ứng dụng
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Management', // Tiêu đề ứng dụng
      debugShowCheckedModeBanner: false, // Ẩn banner debug
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Sử dụng Material Design 3
        scaffoldBackgroundColor: const Color(0xFF0F0F0F), // Màu nền tối
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F0F),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: const MainScreen(), // Màn hình chính
    );
  }
}

/// Màn hình chính chứa bottom navigation và quản lý các tab
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Index của tab đang chọn
  
  // Danh sách các màn hình tương ứng với các tab
  final List<Widget> _screens = [
    const HomeScreen(), // Tab 0: Quản lý nhiệm vụ
    const ScheduleScreen(), // Tab 1: Lịch
    const FocusScreen(), // Tab 2: Tập trung
    const StatsScreen(), // Tab 3: Thống kê
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack giữ trạng thái của tất cả các tab khi chuyển đổi
      body: IndexedStack(index: _selectedIndex, children: _screens),
      
      // Bottom navigation bar với badge hiển thị số nhiệm vụ chưa hoàn thành
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        // Lắng nghe thay đổi từ Firebase để cập nhật badge real-time
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('isCompleted', isEqualTo: false) // Chỉ lấy tasks chưa xong
            .snapshots(),
        builder: (context, snapshot) {
          int pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

          return ConvexAppBar(
            style: TabStyle.reactCircle, // Style hiệu ứng vòng tròn
            backgroundColor: const Color(0xFF1A1A1A),
            color: Colors.white24, // Màu icon không active
            activeColor: Colors.blueAccent, // Màu icon active
            items: [
              // Tab 1: HOME - Hiển thị badge số nhiệm vụ chưa xong
              TabItem(
                icon: pendingCount > 0
                    ? badges.Badge(
                        badgeContent: Text(
                          '$pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                        child: const Icon(Icons.home, color: Colors.white24),
                      )
                    : Icons.home,
                title: 'HOME',
              ),
              // Tab 2: CALENDAR - Lịch nhiệm vụ
              const TabItem(icon: Icons.calendar_month, title: 'CALENDAR'),
              // Tab 3: FOCUS - Tập trung
              const TabItem(icon: Icons.timer, title: 'FOCUS'),
              // Tab 4: STATS - Thống kê
              const TabItem(icon: Icons.bar_chart, title: 'STATS'),
            ],
            initialActiveIndex: _selectedIndex, // Tab mặc định
            onTap: (int i) => setState(() => _selectedIndex = i), // Xử lý khi tap
          );
        },
      ),
    );
  }
}
