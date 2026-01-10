# 📱 DATTDD - Ứng dụng Quản lý Thời gian & Tập trung

Ứng dụng Flutter toàn diện để quản lý nhiệm vụ, lịch trình, tập trung và theo dõi thống kê với tích hợp Firebase và hệ thống thông báo thông minh.

## ✨ Tính năng chính

### 🎯 1. Quản lý Nhiệm vụ (Home Screen)
- **Thêm/Sửa/Xóa nhiệm vụ**: Quản lý danh sách công việc với deadline
- **Mô tả chi tiết**: Thêm ghi chú và chi tiết cho mỗi nhiệm vụ
- **Trạng thái hoàn thành**: Đánh dấu nhiệm vụ đã hoàn thành
- **Thông báo 4 lần**: 1 ngày trước, 3 giờ trước, 30 phút trước, và đúng giờ
- **Tích hợp Firebase Firestore**: Đồng bộ dữ liệu real-time
- **Phần thưởng**: Nhận 10 coins khi hoàn thành nhiệm vụ

### 📅 2. Lịch trình (Schedule Screen)
- **Hiển thị lịch tháng**: Calendar view với `table_calendar`
- **Xem nhiệm vụ theo ngày**: Danh sách nhiệm vụ của ngày được chọn
- **Đánh dấu ngày quan trọng**: Highlight các ngày có nhiệm vụ
- **Thêm nhiệm vụ nhanh**: FAB để tạo nhiệm vụ mới trực tiếp từ lịch

### 🔥 3. Focus Session (Focus Screen)
- **Pomodoro Timer**: Đếm giờ tập trung với giao diện đẹp
- **Work/Rest Mode**: Chuyển đổi giữa chế độ làm việc và nghỉ ngơi
- **Deep Focus Mode**: Cảnh báo khi rời khỏi app (ngăn mất tập trung)
- **Âm nhạc nền**: Phát nhạc tự động khi làm việc
- **Streak Counter**: Theo dõi chuỗi ngày tập trung liên tục
- **Progress Tracking**: Thống kê thời gian tập trung hàng ngày
- **Wheel Picker**: Chọn giờ/phút với giao diện scroll mượt mà

### 📊 4. Thống kê (Stats Screen)
- **Biểu đồ tuần**: Bar chart thể hiện phút tập trung mỗi ngày
- **Tổng kết**: Hiển thị tổng thời gian, streak, coins
- **Nhiệm vụ hoàn thành**: Danh sách nhiệm vụ đã hoàn thành với thời gian

### ✅ 5. Nhiệm vụ đã hoàn thành (Completed Tasks Screen)
- **Lịch sử**: Xem tất cả nhiệm vụ đã hoàn thành
- **Chi tiết**: Thời gian hoàn thành, mô tả
- **Khôi phục**: Đánh dấu lại chưa hoàn thành nếu cần

### 🔔 6. Hệ thống Thông báo
- **Exact Alarm**: Sử dụng exact alarm cho Android 12+
- **4 lần nhắc nhở**:
  - 📅 1 ngày trước deadline
  - ⏰ 3 giờ trước deadline
  - ⚠️ 30 phút trước deadline
  - 🔴 Đúng giờ deadline
- **Full Screen Intent**: Thông báo toàn màn hình cho alarm
- **Timezone Support**: Hỗ trợ múi giờ Việt Nam
- **Test Notification**: Gửi thông báo test để kiểm tra hệ thống

## 📁 Cấu trúc Project

```
lib/
├── main.dart                      # Entry point, MainScreen với bottom navigation
├── models.dart                    # Data models: Task, Project, UserStats, ChecklistItem
├── firebase_options.dart          # Firebase configuration
│
├── home_screen.dart               # 🏠 Màn hình chính: Quản lý nhiệm vụ
├── schedule_screen.dart           # 📅 Màn hình lịch: Calendar view
├── focus_screen.dart              # 🔥 Màn hình tập trung: Pomodoro timer
├── stats_screen.dart              # 📊 Màn hình thống kê: Charts & progress
├── completed_tasks_screen.dart    # ✅ Màn hình nhiệm vụ đã hoàn thành
│
└── notification_service.dart      # 🔔 Service quản lý thông báo

android/
└── app/
    └── src/
        └── main/
            └── AndroidManifest.xml    # Android permissions & receivers
```

## 🎨 Chi tiết các màn hình

### 🏠 Home Screen (`home_screen.dart`)
**Chức năng:**
- Hiển thị danh sách nhiệm vụ chưa hoàn thành
- Thêm nhiệm vụ mới với dialog
- Chỉnh sửa nhiệm vụ
- Xóa nhiệm vụ với xác nhận
- Đánh dấu hoàn thành (nhận 10 coins)
- Badge hiển thị số lượng nhiệm vụ

**UI Components:**
- ListView với TaskCard
- FloatingActionButton để thêm task
- Dialog form với validation
- SnackBar thông báo

### 📅 Schedule Screen (`schedule_screen.dart`)
**Chức năng:**
- TableCalendar hiển thị lịch tháng
- Đánh dấu ngày có nhiệm vụ
- Hiển thị nhiệm vụ của ngày được chọn
- Navigate qua các tháng
- Thêm nhiệm vụ cho ngày cụ thể

**UI Components:**
- TableCalendar widget
- ListView cho tasks của ngày
- Date picker integration
- Event markers

### 🔥 Focus Screen (`focus_screen.dart`)
**Chức năng:**
- Timer đếm ngược với hours:minutes:seconds
- FixedExtentScrollController cho wheel picker
- Background music player (AudioPlayer)
- Deep Focus Mode với AppLifecycleState monitoring
- Streak counter animation
- Progress bar cho mục tiêu hàng ngày (120 phút)
- Work/Rest mode switching

**UI Components:**
- Custom wheel picker với ListWheelScrollView
- Circular progress indicators
- Play/Pause/Reset/Skip buttons
- Alarm sound selector
- Deep Focus toggle
- Streak counter với fire icon animation

**State Management:**
- Timer management với periodic updates
- Firebase Firestore integration cho focus sessions
- Local notifications cho violations

### 📊 Stats Screen (`stats_screen.dart`)
**Chức năng:**
- Bar chart hiển thị phút tập trung 7 ngày
- Tổng kết: Total time, Streak, Coins
- Danh sách nhiệm vụ đã hoàn thành
- Navigate đến Completed Tasks Screen

**UI Components:**
- fl_chart BarChart
- Stats cards
- Task list
- Navigation button

### ✅ Completed Tasks Screen (`completed_tasks_screen.dart`)
**Chức năng:**
- ListView tất cả nhiệm vụ đã hoàn thành
- Hiển thị thời gian hoàn thành
- Khôi phục task (đánh dấu chưa hoàn thành)

## 🛠️ Công nghệ & Dependencies

### Core
- **Flutter SDK**: ^3.10.1
- **Dart**: ^3.0.0

### State Management
- **flutter/material.dart**: Material Design components
- Built-in StatefulWidget với setState

### Backend & Database
- **firebase_core**: ^3.9.0 - Firebase initialization
- **cloud_firestore**: ^5.5.2 - NoSQL database
- **firebase_auth**: ^5.3.4 - Authentication (optional)

### UI Components
- **table_calendar**: ^3.1.1 - Calendar widget
- **intl**: ^0.19.0 - Date formatting & localization
- **badges**: ^3.1.2 - Badge indicators
- **convex_bottom_bar**: ^3.2.0 - Custom bottom navigation
- **flutter_animate**: ^4.5.0 - Animations

### Media & Audio
- **audioplayers**: ^6.1.0 - Background music player
- **vibration**: ^2.0.0 - Haptic feedback

### Notifications
- **flutter_local_notifications**: ^18.0.1 - Local notifications
- **timezone**: ^0.9.4 - Timezone support

### Permissions
- **permission_handler**: ^11.3.1 - Runtime permissions

### Charts
- **fl_chart**: ^0.69.2 - Charts & graphs

### Utilities
- **device_info_plus**: ^10.1.2 - Device information
- **path_provider**: ^2.1.5 - File paths

## 🚀 Cài đặt & Chạy

### 1. Prerequisites
- Flutter SDK (3.10.1 trở lên)
- Android Studio / VS Code
- Firebase project đã cấu hình

### 2. Clone & Install
```bash
git clone https://github.com/VanThai1704/DATTDD.git
cd DATTDD
flutter pub get
```

### 3. Firebase Setup
- Tạo project trên Firebase Console
- Download `google-services.json` (Android) và đặt vào `android/app/`
- Download `GoogleService-Info.plist` (iOS) và đặt vào `ios/Runner/`
- Chạy: `flutterfire configure`

### 4. Chạy app
```bash
flutter run
```

## 🔧 Cấu hình quan trọng

### Android Permissions (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
```

### Notification Receivers
```xml
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
    </intent-filter>
</receiver>
```

## 📊 Firebase Collections

### `tasks`
```dart
{
  'title': String,
  'description': String,
  'deadline': String,        // Format: 'yyyy-MM-dd'
  'deadlineTime': String,    // Format: 'HH:mm'
  'isCompleted': bool,
  'completedAt': Timestamp?,
  'createdAt': Timestamp,
  'priority': int,           // 0: low, 1: medium, 2: high
}
```

### `focus_sessions`
```dart
{
  'duration': int,           // Minutes
  'date': String,            // Format: 'yyyy-MM-dd'
  'createdAt': Timestamp,
  'taskId': String?,
  'taskTitle': String?,
}
```

### `user_profile`
```dart
{
  'coins': int,
  'streakFreezes': int,
  'currentStreak': int,
  'lastStreakDate': Timestamp?,
}
```

## 🎯 Tính năng nổi bật

### 1. Exact Alarm System
- Hỗ trợ Android 12+ với exact alarm permission
- 4 mức độ nhắc nhở tăng dần
- Không bị ảnh hưởng bởi battery optimization

### 2. Deep Focus Mode
- Phát hiện khi người dùng thoát app
- Cảnh báo rung và notification
- Giúp duy trì tập trung cao độ

### 3. Gamification
- Coins system (10 coins/task hoàn thành)
- Streak tracking
- Progress visualization

### 4. Smart Notifications
- Test notification để verify hệ thống
- Debug logs chi tiết
- Timezone-aware scheduling

## 🐛 Troubleshooting

### Thông báo không hoạt động
1. Kiểm tra permissions đã được cấp
2. Tắt battery optimization cho app
3. Xem logs để debug
4. Test với test notification

### Build errors
```bash
flutter clean
flutter pub get
flutter run
```

### Firebase errors
- Kiểm tra `google-services.json` đã đúng vị trí
- Verify Firebase project configuration
- Check Firestore rules

## 👨‍💻 Development

### Code Style
- Follow Flutter/Dart conventions
- Use meaningful variable names
- Comment complex logic
- Format code: `dart format .`

### Git Workflow
```bash
git add .
git commit -m "feat: description"
git push origin main
```

## 📝 License

MIT License - Free to use and modify

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📧 Contact

- GitHub: [VanThai1704](https://github.com/VanThai1704)
- Project: [DATTDD](https://github.com/VanThai1704/DATTDD)

---

Made with ❤️ using Flutter

### Notification System
- `Timer.periodic` để kiểm tra định kỳ mỗi phút
- `Set<String>` để lưu các event đã gửi thông báo, tránh trùng lặp
- Parse thời gian từ string với regex để tính toán chính xác

## 📝 Lưu ý

- ⚠️ Dữ liệu hiện tại lưu trong memory, sẽ mất khi đóng app
- ⚠️ HomeScreen và ScheduleScreen sử dụng dữ liệu riêng biệt (chưa đồng bộ)
- ✅ Đã xử lý các lỗi: Navigator lock, TextEditingController disposal, State update timing

## 🔮 Tính năng tương lai

- [ ] Lưu trữ dữ liệu với SharedPreferences hoặc database
- [ ] Đồng bộ dữ liệu giữa các màn hình
- [ ] Thêm tùy chọn lặp lại sự kiện (hàng ngày, hàng tuần)
- [ ] Thêm tùy chọn thông báo tùy chỉnh (5 phút, 30 phút trước)
- [ ] Thêm chủ đề (theme) tùy chỉnh
- [ ] Export/Import dữ liệu

## 👨‍💻 Tác giả

Dự án Flutter - Quản lý Thời gian
