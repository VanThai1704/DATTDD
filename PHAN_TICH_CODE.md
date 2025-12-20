# Phân tích Code - DATTDD

## 📊 Tổng quan kiến trúc

Ứng dụng sử dụng kiến trúc đơn giản với 3 file chính:
- `main.dart`: Entry point và navigation
- `home_screen.dart`: Quản lý sự kiện và nhiệm vụ
- `schedule_screen.dart`: Hiển thị lịch và sự kiện theo ngày

---

## 🔍 Phân tích chi tiết từng component

### 1. Model Classes

#### Event Model (`lib/home_screen.dart:8-22`)
```dart
class Event {
  final String title;
  final String time;
  final DateTime? date;  // ⭐ Quan trọng: Cho phép null
  final IconData icon;
  final Color color;
}
```

**Phân tích:**
- `date` là nullable (`DateTime?`) để hỗ trợ sự kiện không có ngày cụ thể
- Sử dụng `final` để đảm bảo immutability
- `time` lưu dạng string (VD: "10:00 AM - 11:00 AM") để dễ hiển thị

#### Task Model (`lib/home_screen.dart:24-33`)
```dart
class Task {
  final String title;
  final String deadline;
}
```

**Phân tích:**
- Model đơn giản, chỉ cần 2 trường
- `deadline` lưu dạng string với format "Hạn chót: ..."

---

### 2. Notification System (`lib/home_screen.dart:42-197`)

#### Khởi tạo Notifications (`_initializeNotifications`)
```dart
Future<void> _initializeNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(...);
  await _notifications.initialize(initSettings, ...);
  // Yêu cầu quyền trên Android 13+
  await androidPlugin.requestNotificationsPermission();
}
```

**Phân tích:**
- Hỗ trợ cả Android và iOS
- Yêu cầu quyền notification trên Android 13+
- Sử dụng icon launcher làm icon mặc định

#### Timer kiểm tra định kỳ (`_startNotificationChecker`)
```dart
void _startNotificationChecker() {
  _notificationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
    _checkUpcomingEvents();
  });
  _checkUpcomingEvents(); // Kiểm tra ngay lập tức
}
```

**Phân tích:**
- `Timer.periodic` chạy mỗi 1 phút
- Kiểm tra ngay khi khởi động để không bỏ lỡ sự kiện sắp tới
- Quan trọng: Hủy timer trong `dispose()` để tránh memory leak

#### Logic kiểm tra sự kiện (`_checkUpcomingEvents`)
```dart
void _checkUpcomingEvents() {
  final now = DateTime.now();
  for (int i = 0; i < _events.length; i++) {
    final event = _events[i];
    if (event.date == null) continue; // Bỏ qua nếu không có ngày
    
    // Parse thời gian từ string
    final startTime = _parseTimeFromString(event.time);
    if (startTime == null) continue;
    
    // Tạo DateTime cho thời điểm bắt đầu
    final eventDateTime = DateTime(
      event.date!.year, event.date!.month, event.date!.day,
      startTime.hour, startTime.minute,
    );
    
    // Tính khoảng cách
    final difference = eventDateTime.difference(now);
    final minutesUntilEvent = difference.inMinutes;
    final secondsUntilEvent = difference.inSeconds;
    
    // Tạo key duy nhất
    final eventKey = '${event.title}_${eventDateTime.millisecondsSinceEpoch}';
    
    // Thông báo 15 phút trước
    if (minutesUntilEvent > 0 && minutesUntilEvent <= 15 && 
        !_notifiedEvents.contains(eventKey)) {
      _showNotification('Sự kiện sắp tới', '${event.title} sẽ bắt đầu trong ${minutesUntilEvent} phút');
      _notifiedEvents.add(eventKey);
    }
    
    // Thông báo khi bắt đầu
    if (minutesUntilEvent == 0 && secondsUntilEvent >= 0 && 
        !_notifiedStartEvents.contains(startEventKey)) {
      _showNotification('Sự kiện đã bắt đầu', '${event.title} đã bắt đầu lúc ${_formatTimeOfDay(startTime)}');
      _notifiedStartEvents.add(startEventKey);
    }
  }
}
```

**Phân tích:**
- ⭐ **Parse thời gian**: Chuyển string "10:00 AM - 11:00 AM" thành `TimeOfDay`
- ⭐ **Tạo DateTime**: Kết hợp ngày và giờ để có thời điểm chính xác
- ⭐ **Tính toán khoảng cách**: Sử dụng `difference()` để tính phút/giây còn lại
- ⭐ **Tránh trùng lặp**: Dùng `Set<String>` với key duy nhất
- ⭐ **2 loại thông báo**: 
  - "Sắp tới" (1-15 phút trước)
  - "Bắt đầu" (đúng giờ, trong vòng 1 phút đầu)

#### Parse thời gian từ string (`_parseTimeFromString`)
```dart
TimeOfDay? _parseTimeFromString(String timeString) {
  try {
    final parts = timeString.split(' - ');
    final startTimeStr = parts[0].trim();
    // Regex: "10:00 AM" hoặc "10:00AM"
    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false)
        .firstMatch(startTimeStr);
    if (timeMatch == null) return null;
    
    int hour = int.parse(timeMatch.group(1)!);
    int minute = int.parse(timeMatch.group(2)!);
    final period = timeMatch.group(3)!.toUpperCase();
    
    // Chuyển đổi 12h sang 24h
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    
    return TimeOfDay(hour: hour, minute: minute);
  } catch (e) {
    return null;
  }
}
```

**Phân tích:**
- ⭐ Sử dụng **Regex** để parse format "HH:MM AM/PM"
- ⭐ Xử lý cả "10:00 AM" và "10:00AM" (có/không có space)
- ⭐ Chuyển đổi 12h format sang 24h format
- ⭐ Trả về `null` nếu parse thất bại (safe)

---

### 3. Dialog Management

#### PopScope Pattern (`lib/home_screen.dart:915-921`)
```dart
return PopScope(
  canPop: true,
  onPopInvoked: (didPop) {
    if (didPop) {
      titleController.dispose(); // ⭐ Dispose an toàn
    }
  },
  child: AlertDialog(...)
);
```

**Phân tích:**
- ⭐ **PopScope** thay thế `WillPopScope` (deprecated)
- ⭐ **onPopInvoked**: Được gọi khi dialog đóng (bất kỳ cách nào)
- ⭐ **Dispose controller**: Chỉ dispose 1 lần, tránh lỗi "used after disposed"

#### State Update Pattern (`lib/home_screen.dart:1147-1156`)
```dart
// Đóng dialog trước
Navigator.pop(dialogContext);

// Cập nhật state sau khi dialog đóng
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) {
    setState(() {
      _events.add(newEvent);
    });
    _showNotification('Sự kiện mới', 'Đã thêm: $eventTitle');
  }
});
```

**Phân tích:**
- ⭐ **Thứ tự quan trọng**: Đóng dialog → Đợi frame tiếp theo → Cập nhật state
- ⭐ **addPostFrameCallback**: Đảm bảo UI đã render xong trước khi cập nhật
- ⭐ **mounted check**: Tránh lỗi khi widget đã dispose
- ⭐ **Lưu giá trị trước**: Đọc từ controller trước khi đóng dialog

#### StatefulBuilder cho Dialog State (`lib/home_screen.dart:913-914`)
```dart
return StatefulBuilder(
  builder: (context, setDialogState) {
    // setDialogState để cập nhật UI trong dialog
  }
);
```

**Phân tích:**
- ⭐ Cần `StatefulBuilder` vì dialog là widget tĩnh
- ⭐ `setDialogState` để cập nhật UI khi chọn ngày/giờ/icon/màu
- ⭐ Không ảnh hưởng đến state của widget cha

---

### 4. Icon Selection (Thay thế DropdownButton)

#### Wrap với GestureDetector (`lib/home_screen.dart:1005-1044`)
```dart
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    Icons.event, Icons.group, Icons.assignment, Icons.school, Icons.work,
  ].map((icon) {
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          selectedIcon = icon;
        });
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: selectedIcon == icon
              ? Colors.blue.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: selectedIcon == icon ? Colors.blue : Colors.grey.withOpacity(0.3),
            width: selectedIcon == icon ? 2 : 1,
          ),
        ),
        child: Icon(icon, ...),
      ),
    );
  }).toList(),
)
```

**Phân tích:**
- ⭐ **Vấn đề**: `DropdownButton` sử dụng `Navigator` nội bộ, gây xung đột với dialog
- ⭐ **Giải pháp**: Dùng `Wrap` + `GestureDetector` để chọn trực tiếp
- ⭐ **Visual feedback**: Highlight icon được chọn với màu và border
- ⭐ **Responsive**: `Wrap` tự động xuống dòng khi không đủ chỗ

---

### 5. Calendar Integration (`lib/schedule_screen.dart`)

#### Marked Days System (`lib/schedule_screen.dart:20-151`)
```dart
Set<DateTime> _markedDays = {};

bool _isMarked(DateTime day) {
  final normalizedDay = DateTime.utc(day.year, day.month, day.day);
  return _markedDays.contains(normalizedDay);
}

void _toggleMarkDay(DateTime day) {
  final normalizedDay = DateTime.utc(day.year, day.month, day.day);
  setState(() {
    if (_markedDays.contains(normalizedDay)) {
      _markedDays.remove(normalizedDay);
    } else {
      _markedDays.add(normalizedDay);
    }
  });
}
```

**Phân tích:**
- ⭐ **Normalize DateTime**: Dùng `DateTime.utc()` để loại bỏ time component
- ⭐ **Set<DateTime>**: Hiệu quả cho việc kiểm tra membership (O(1))
- ⭐ **Visual**: Hiển thị marker cam và border cam cho ngày được đánh dấu

#### Calendar Builders (`lib/schedule_screen.dart:197-267`)
```dart
calendarBuilders: CalendarBuilders(
  markerBuilder: (context, date, events) {
    if (_isMarked(date)) {
      return Positioned(
        bottom: 1,
        child: Container(
          width: 7, height: 7,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    return null;
  },
  defaultBuilder: (context, date, focused) {
    if (_isMarked(date) && !isSameDay(_selectedDay, date)) {
      return Container(
        margin: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.orange, width: 1.5),
        ),
        child: Center(child: Text('${date.day}', ...)),
      );
    }
    return null;
  },
  selectedBuilder: (context, date, focused) {
    if (_isMarked(date)) {
      // Kết hợp màu selected và màu marked
      return Container(...);
    }
    return null;
  },
)
```

**Phân tích:**
- ⭐ **markerBuilder**: Thêm marker nhỏ ở góc dưới
- ⭐ **defaultBuilder**: Tùy chỉnh ngày bình thường (không selected)
- ⭐ **selectedBuilder**: Tùy chỉnh ngày được chọn
- ⭐ **Layering**: Có thể kết hợp nhiều trạng thái (selected + marked)

---

### 6. Validation và Error Handling

#### Form Validation (`lib/home_screen.dart:1088-1136`)
```dart
ElevatedButton(
  onPressed: () {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên sự kiện'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (selectedDate == null) { ... }
    if (startTime == null) { ... }
    if (endTime == null) { ... }
    
    // Kiểm tra logic: giờ kết thúc > giờ bắt đầu
    final startMinutes = startTime!.hour * 60 + startTime!.minute;
    final endMinutes = endTime!.hour * 60 + endTime!.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(...);
      return;
    }
    // Lưu dữ liệu...
  },
)
```

**Phân tích:**
- ⭐ **Validation từng bước**: Kiểm tra từng trường một
- ⭐ **SnackBar feedback**: Hiển thị lỗi rõ ràng cho người dùng
- ⭐ **Logic validation**: Kiểm tra giờ kết thúc phải sau giờ bắt đầu
- ⭐ **Early return**: Dừng ngay khi có lỗi, không tiếp tục xử lý

---

### 7. Import Alias (Giải quyết xung đột tên)

#### Scheduler Import (`lib/home_screen.dart:3`)
```dart
import 'package:flutter/scheduler.dart' as scheduler;
```

**Phân tích:**
- ⭐ **Vấn đề**: `Priority` có trong cả `scheduler.dart` và `flutter_local_notifications`
- ⭐ **Giải pháp**: Dùng alias `as scheduler` để phân biệt
- ⭐ **Sử dụng**: `scheduler.SchedulerBinding` thay vì `SchedulerBinding`

---

## 🎯 Điểm mạnh của code

1. ✅ **Error handling tốt**: Xử lý null, parse errors, validation
2. ✅ **Memory management**: Dispose controllers, cancel timers
3. ✅ **User experience**: SnackBar feedback, visual indicators
4. ✅ **Code organization**: Tách biệt logic rõ ràng
5. ✅ **Reusable functions**: `_formatTimeOfDay`, `_formatDate`, `_parseTimeFromString`

## ⚠️ Điểm cần cải thiện

1. ⚠️ **Data persistence**: Dữ liệu chỉ lưu trong memory
2. ⚠️ **Data synchronization**: HomeScreen và ScheduleScreen dùng dữ liệu riêng
3. ⚠️ **Hardcoded values**: Icon list, color list nên tách ra constants
4. ⚠️ **Error messages**: Nên dùng localization thay vì hardcode tiếng Việt
5. ⚠️ **Testing**: Chưa có unit tests

## 🔧 Các kỹ thuật đã áp dụng

1. **State Management**: `StatefulWidget` + `setState`
2. **Lifecycle Management**: `initState`, `dispose`, `mounted` check
3. **Async Operations**: `Future`, `async/await` cho date/time pickers
4. **Timer**: `Timer.periodic` cho notification checking
5. **Regex Parsing**: Parse time string với pattern matching
6. **Set Operations**: Dùng Set để tránh duplicate notifications
7. **Widget Composition**: Tách thành các widget nhỏ (`_buildTodayEvent`, `_buildUpcomingTask`)
8. **Dialog Management**: `PopScope`, `StatefulBuilder`, `Navigator.pop`

---

## 📚 Bài học rút ra

1. **Navigator conflicts**: Tránh dùng `DropdownButton` trong dialog, dùng custom widget
2. **Controller disposal**: Chỉ dispose 1 lần, tốt nhất trong `PopScope.onPopInvoked`
3. **State update timing**: Dùng `addPostFrameCallback` để cập nhật sau khi dialog đóng
4. **DateTime normalization**: Luôn normalize khi so sánh ngày (loại bỏ time component)
5. **Notification deduplication**: Dùng Set với key duy nhất để tránh trùng lặp

