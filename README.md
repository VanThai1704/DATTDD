# 📱 DATTDD - Ứng dụng Quản lý Thời gian & Tập trung

Ứng dụng Flutter toàn diện để quản lý nhiệm vụ, lịch trình, tập trung và theo dõi thống kê với tích hợp Firebase và hệ thống thông báo thông minh.

## ✨ Tính năng chính

### 🎯 1. Quản lý Nhiệm vụ Nâng cao (Home Screen)
- **CRUD Nhiệm vụ**: Thêm/Sửa/Xóa với giao diện mượt mà
- **Quick Add ⚡**: Floating button thêm nhanh nhiệm vụ
- **Recurring Tasks**: Lặp lại hàng ngày/tuần/tháng
- **Tags System**: Phân loại với tags tùy chỉnh
- **Search & Filter**: 
  - Tìm kiếm theo tên
  - Lọc theo project
  - Lọc theo tags
  - Toggle hiện/ẩn tasks đã hoàn thành
- **Priority Levels**: High/Medium/Low với màu sắc riêng
- **Projects**: Nhóm nhiệm vụ theo dự án
- **Checklist**: Subtasks cho nhiệm vụ phức tạp
- **Deadline & Duration**: Đặt thời hạn và ước tính thời gian
- **Thông báo thông minh**: 4 lần nhắc (1 ngày, 3 giờ, 30 phút, đúng giờ)
- **Phần thưởng**: Nhận 10 coins khi hoàn thành
- **Auto-create**: Tasks tự động tạo lại theo recurring

### 📅 2. Lịch trình Tương tác (Schedule Screen)
- **Calendar View**: Month/Week view với `table_calendar`
- **Color Coding**: Màu sắc theo priority hoặc project (toggle)
- **Quick Edit**: Long press để edit nhanh
  - Mark complete/incomplete
  - Reschedule to tomorrow
  - Delete task
- **Timeline View**: Hiển thị tasks theo giờ trong ngày
- **Visual Indicators**: Icons cho overdue tasks
- **Event Markers**: Đánh dấu ngày có nhiệm vụ

### 🔥 3. Focus Session Nâng cao (Focus Screen)
- **Preset Times**: Nút nhanh 25/45/90 phút (work) và 5/15 phút (break)
- **Custom Timer**: Wheel picker cho giờ/phút tùy chỉnh
- **Work/Rest Mode**: Tự động chuyển đổi với countdown
- **Deep Focus Mode**: Cảnh báo khi rời app
- **Pause với lý do**: Tracking tại sao pause
- **Alarm Sounds**: 6 options (Default, Piano, Zen, Nature, Chimes, Bell)
- **White Noise**: 6 options (None, Rain, Ocean, Forest, Fireplace, Cafe)
- **Project Tracking**: Link focus session với project
- **Streak Counter**: Chuỗi ngày tập trung liên tục
- **Daily Progress**: Target 120 phút/ngày
- **Wheel Picker**: Chọn thời gian mượt mà
- **Completion Dialog**: Xác nhận hoàn thành task sau session

### 📊 4. Thống kê Chi tiết (Stats Screen)
- **Productivity Score**: Điểm 0-100 với insights
- **Task Pie Chart**: Breakdown completed/pending/overdue
- **Weekly Bar Chart**: Focus activity 7 ngày
- **View Modes**: Toggle Week/Month/Quarter
- **Best Focus Time**: Phân tích giờ làm việc hiệu quả nhất
- **Streak System**: Track chuỗi ngày active
- **Coins Wallet**: Hiển thị coins kiếm được
- **Streak Protection Shop**: Mua Freeze với 50 coins
- **Focus Summary**: Tổng thời gian tập trung
- **Completed Tasks Counter**: Số nhiệm vụ hoàn thành

### ✅ 5. Lịch sử Hoàn thành (Completed Tasks Screen)
- **Timeline**: Xem theo thời gian hoàn thành
- **Details**: Đầy đủ thông tin task
- **Restore**: Đánh dấu lại chưa hoàn thành
- **Filter**: Tìm kiếm trong lịch sử

### 🔔 6. Hệ thống Thông báo Thông minh
- **Priority-based**: Importance dựa trên task priority
- **Snooze Actions**: 5 phút, 15 phút
- **Mark Done**: Action button trên notification
- **4 lần nhắc nhở**:
  - 📅 1 ngày trước (High importance)
  - ⏰ 3 giờ trước (High importance)
  - ⚠️ 30 phút trước (Max importance)
  - 🔴 Đúng giờ (Max + Full screen)
- **Exact Alarm**: Android 12+ support
- **Timezone**: Hỗ trợ Asia/Ho_Chi_Minh
- **Categorization**: Proper notification channels

## 📁 Cấu trúc Project

```
lib/
├── main.dart                      # Entry point, ConvexAppBar navigation
├── models.dart                    # Models: Task, Project, UserStats, RecurringType
├── firebase_options.dart          # Firebase configuration
│
├── home_screen.dart               # 🏠 Task management với search/filter/tags
├── schedule_screen.dart           # 📅 Interactive calendar với quick edit
├── focus_screen.dart              # 🔥 Advanced pomodoro với presets/white noise
├── stats_screen.dart              # 📊 Comprehensive analytics & insights
├── completed_tasks_screen.dart    # ✅ History của completed tasks
│
└── notification_service.dart      # 🔔 Smart notification system

android/
└── app/
    └── src/
        └── main/
            └── AndroidManifest.xml    # Permissions & receivers
```

## 🎨 Chi tiết các màn hình

### 🏠 Home Screen (`home_screen.dart`)
**Chức năng:**
- Dual floating buttons (Quick Add ⚡ + Full Add +)
- Search bar với clear button
- Filter chips: Projects, Tags, Completed toggle
- Task cards với priority colors
- Recurring indicators
- Tags display
- Shimmer loading
- Empty state

**UI Components:**
- CustomScrollView với SliverAppBar
- TextField search
- ChoiceChip/FilterChip filters
- Animated task cards
- Quick add dialog (minimal)
- Full add dialog (complete form)

### 📅 Schedule Screen (`schedule_screen.dart`)
**Chức năng:**
- Month/Week toggle
- Color by Priority/Project toggle
- Long press quick actions
- Timeline view với time indicators
- Task cards với deadline visual
- Overdue warnings

**UI Components:**
- TableCalendar
- IntrinsicHeight timeline
- GestureDetector long press
- AlertDialog quick actions
- Priority/Project color borders
- ListView cho tasks của ngày
- Date picker integration
- Event markers

### 🔥 Focus Screen (`focus_screen.dart`)
**Chức năng:**
- **Preset Times**: 6 quick buttons
  - Work presets: 25/45/90 phút
  - Break presets: 5/15 phút
  - Tự động set thời gian + màu sắc phù hợp
- **Custom Timer**: Wheel picker cho hours:minutes:seconds tùy chỉnh
- **White Noise**: 6 tùy chọn âm thanh nền
  - None, Rain, Ocean, Forest, Fireplace, Cafe
  - Âm thanh loop suốt session
- **Pause với lý do**: Dialog track lý do tại sao pause
  - Quick Break, Distraction, Task Complete, Other
  - Lưu vào session history
- **Project Tracking**: Dropdown selector link session với project
- **Alarm Sounds**: 6 tùy chọn (Default, Piano, Zen, Nature, Chimes, Bell)
- **Deep Focus Mode**: Monitor app lifecycle, cảnh báo vi phạm
- **Streak Counter**: Animation khi tăng streak
- **Progress Bar**: Target 120 phút/ngày với % và visualizer
- **Work/Rest Mode**: Auto toggle màu sắc và âm nhạc

**UI Components:**
- Preset buttons grid (2x3) với màu phân biệt
- Custom wheel picker với ListWheelScrollView
- White noise selector với icons
- Project dropdown với colors
- Pause reason dialog với radio buttons
- Circular progress indicators
- Play/Pause/Reset/Skip buttons với icons
- Streak counter với fire icon animation
- Completion dialog với task link

**State Management:**
- Timer với _isRunning, _remainingSeconds
- Pause display fix: Show countdown when _isRunning OR _remainingSeconds > 0
- AudioPlayer cho music và white noise
- AppLifecycleState monitoring
- Firebase Firestore save sessions với:
  - startTime, endTime, duration
  - isCompleted, deepFocusEnabled
  - violationCount, alarmUsed, whiteNoiseUsed, projectId

### 📊 Stats Screen (`stats_screen.dart`)
**Chức năng:**
- **Productivity Score**: 0-100 với insights
  - Base: Completion rate × 70
  - Bonus: Streak × 2 (max 30)
  - Color-coded: Poor/Average/Good/Excellent
- **Task Pie Chart**: 3 segments
  - Completed (Green)
  - Pending (Orange)
  - Overdue (Red)
  - Hiển thị count và %
- **Weekly Bar Chart**: 7 ngày focus activity
- **View Mode Toggle**: 3 options
  - Week: Last 7 days
  - Month: Last 30 days
  - Quarter: Last 90 days
  - Update charts theo selection
- **Best Focus Time**: Hourly analysis
  - Hiển thị giờ làm việc hiệu quả nhất
  - Show total minutes và clock icon
  - "No data" fallback
- **Streak System**: Daily tracking
- **Coins Wallet**: Display total coins
- **Focus Summary**: Total time formatted
- **Completed Tasks Counter**: Số tasks hoàn thành

**UI Components:**
- Productivity score card với color indicator
- PieChart từ fl_chart với legends
- BarChart với gradient colors
- SegmentedButton cho view mode toggle
- Best focus time card
- Stats summary cards
- Navigation button đến Completed Tasks

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
  'deadline': String,         // Format: 'yyyy-MM-dd'
  'deadlineTime': String,     // Format: 'HH:mm'
  'isCompleted': bool,
  'completedAt': Timestamp?,
  'createdAt': Timestamp,
  'priority': int,            // 0: low, 1: medium, 2: high
  'projectId': String?,       // Link to project
  'tags': List<String>,       // Tags array
  'recurring': String,        // 'none', 'daily', 'weekly', 'monthly'
  'recurringSourceId': String?, // Link to original recurring task
  'estimatedDuration': int?,  // Phút ước tính
  'checklist': List<Map>,     // Subtasks
}
```

### `projects`
```dart
{
  'name': String,
  'description': String,
  'color': int,               // Color value
  'createdAt': Timestamp,
  'isArchived': bool,
}
```

### `focus_sessions`
```dart
{
  'duration': int,            // Minutes
  'date': String,             // Format: 'yyyy-MM-dd'
  'startTime': Timestamp,
  'endTime': Timestamp,
  'createdAt': Timestamp,
  'isCompleted': bool,
  'taskId': String?,
  'taskTitle': String?,
  'projectId': String?,       // New: Link to project
  'deepFocusEnabled': bool,
  'violationCount': int,
  'alarmUsed': String,        // New: Alarm sound selected
  'whiteNoiseUsed': String?,  // New: White noise selected
  'pauseReason': String?,     // New: Why user paused
}
```

### `user_profile`
```dart
{
  'coins': int,
  'streakFreezes': int,
  'currentStreak': int,
  'lastStreakDate': Timestamp?,
  'totalFocusTime': int,      // Total minutes
  'tasksCompleted': int,
}
```

## 🎯 Tính năng nổi bật

### 1. Advanced Task Management
- **Recurring Tasks**: Tasks tự động tạo lại theo schedule
  - Daily: Mỗi ngày tạo mới với same details
  - Weekly: Mỗi tuần
  - Monthly: Mỗi tháng
  - Auto-create khi hoàn thành task recurring
- **Tags System**: Phân loại linh hoạt
  - Unlimited tags per task
  - Filter tasks by tags
  - Visual chips display
- **Search & Filter**: Tìm kiếm và lọc mạnh mẽ
  - Real-time search
  - Multi-criteria filtering
  - Save filter states

### 2. Smart Notification System
- **Priority-based Importance**:
  - High Priority → High importance notification
  - Medium Priority → Default importance
  - Low Priority → Low importance
- **Snooze Actions**:
  - 5 phút snooze
  - 15 phút snooze
  - Action buttons trên notification
- **4 mức độ nhắc nhở**:
  - 📅 1 ngày trước (High importance)
  - ⏰ 3 giờ trước (High importance)
  - ⚠️ 30 phút trước (Max importance)
  - 🔴 Đúng giờ (Max + Full screen)
- **Exact Alarm**: Android 12+ support
- **Timezone-aware**: Asia/Ho_Chi_Minh

### 3. Enhanced Focus Experience
- **Preset Times**: Quick start với 6 preset buttons
- **White Noise**: Ambient sounds giúp tập trung
- **Pause Tracking**: Hiểu tại sao user pause
- **Project Integration**: Link sessions với projects
- **Deep Focus Mode**: Monitor và cảnh báo distractions

### 4. Comprehensive Analytics
- **Productivity Score**: Metric tổng hợp 0-100
- **Pie Charts**: Visual breakdown tasks
- **Best Focus Time**: Hourly analysis
- **View Modes**: Week/Month/Quarter perspectives
- **Trend Analysis**: Track improvement over time

### 5. Interactive Calendar
- **Color Coding**: Priority or Project based
- **Quick Edit**: Long press actions
- **Timeline View**: Hour-by-hour schedule
- **Visual Indicators**: Clear overdue warnings

## 🐛 Troubleshooting

### Thông báo không hoạt động
1. Kiểm tra permissions đã được cấp
2. Tắt battery optimization cho app
3. Verify exact alarm permission (Android 12+)
4. Check notification channel settings

### Recurring tasks không tự động tạo
- Verify task has recurring type set (not 'none')
- Check Firebase Firestore rules
- Ensure task completed (trigger auto-create)

### White noise không phát
- Check audio permissions
- Verify audioplayers package installed
- Test với alarm sounds trước

### Build errors
```bash
flutter clean
flutter pub get
flutter run
```

### Firebase errors
- Kiểm tra `google-services.json` đã đúng vị trí
- Verify Firebase project configuration
- Check Firestore rules và indexes

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

## 📝 Giấy phép

Giấy phép MIT - Tự do sử dụng và chỉnh sửa

## 🤝 Đóng góp

Rất hoan nghênh các đóng góp! Vui lòng thoải mái gửi Pull Request.

## 📧 Liên hệ

- GitHub: [VanThai1704](https://github.com/VanThai1704)
- Dự án: [DATTDD](https://github.com/VanThai1704/DATTDD)

---

Được tạo với ❤️ bằng Flutter

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
