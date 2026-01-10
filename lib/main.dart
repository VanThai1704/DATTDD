import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:datbdd/focus_screen.dart';
import 'package:datbdd/home_screen.dart';
import 'package:datbdd/schedule_screen.dart';
import 'package:datbdd/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:badges/badges.dart' as badges;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await NotificationService.init();
    await _requestPermissions();
  } catch (e) {
    debugPrint('Lỗi khởi tạo: $e');
  }
  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  // Request notification permission
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // Request schedule exact alarm permission (Android 12+)
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const ScheduleScreen(),
    const FocusScreen(),
    const StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('isCompleted', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          int pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

          return ConvexAppBar(
            style: TabStyle.reactCircle,
            backgroundColor: const Color(0xFF1A1A1A),
            color: Colors.white24,
            activeColor: Colors.blueAccent,
            items: [
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
              const TabItem(icon: Icons.calendar_month, title: 'CALENDAR'),
              const TabItem(icon: Icons.timer, title: 'FOCUS'),
              const TabItem(icon: Icons.bar_chart, title: 'STATS'),
            ],
            initialActiveIndex: _selectedIndex,
            onTap: (int i) => setState(() => _selectedIndex = i),
          );
        },
      ),
    );
  }
}
