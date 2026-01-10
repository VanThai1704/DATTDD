# Cập nhật Tính năng Thông báo Thời gian

## 📋 Tóm tắt các thay đổi

Ứng dụng đã được cập nhật để hỗ trợ thêm chức năng **thời gian chính xác** cho sự kiện và nhiệm vụ, kèm theo **thông báo đẩy tự động** khi đến giờ.

---

## ✨ Tính năng mới

### 1. **Event Model - Cập nhật**
- **Trước**: `time` (String) + `date` (DateTime)
- **Sau**: `dateTime` (DateTime) - lưu ngày và giờ chính xác

```dart
final DateTime dateTime; // Thay thế time + date
```

### 2. **Task Model - Cập nhật**
- **Thêm**: `deadlineDateTime` (DateTime)
- **Giữ lại**: `deadline` (String) - để hiển thị định dạng đẹp

```dart
final String deadline; // Hiển thị: "Hạn chót: 20/12/2025 14:30"
final DateTime deadlineDateTime; // Lưu dữ liệu chính xác
```

### 3. **Dialogs - Thêm Time Picker**

#### Thêm/Chỉnh sửa Sự kiện:
- ✅ Chọn **Ngày** (DatePicker)
- ✅ Chọn **Giờ** (TimePicker) - **MỚI**
- ✅ Chọn **Màu sắc**
- ✅ Chọn **Biểu tượng**

#### Thêm/Chỉnh sửa Nhiệm vụ:
- ✅ Chọn **Ngày deadline** (DatePicker)
- ✅ Chọn **Giờ deadline** (TimePicker) - **MỚI**

### 4. **Notification System - Cập nhật**

#### Cho Sự kiện:
- 📢 **Thông báo 15 phút trước**: "Sự kiện X sẽ bắt đầu trong 15 phút"
- 📢 **Thông báo khi đến giờ**: "Sự kiện X đã bắt đầu lúc 14:30"

#### Cho Nhiệm vụ:
- 📢 **Thông báo 15 phút trước**: "Nhiệm vụ X sẽ đến hạn trong 15 phút"
- 📢 **Thông báo khi đến deadline**: "Nhiệm vụ X đã đến hạn lúc 14:30"

Kiểm tra mỗi **1 phút** để đảm bảo không bỏ lỡ thông báo.

---

## 🔄 Firestore Sync

### Cấu trúc dữ liệu mới (Firebase):

**Events Collection:**
```json
{
  "title": "Meeting",
  "dateTime": "2025-01-06T14:30:00Z",
  "icon": 57500,
  "iconFontFamily": "MaterialIcons",
  "color": 4280391411
}
```

**Tasks Collection:**
```json
{
  "title": "Complete project",
  "deadline": "Hạn chót: 20/12/2025 14:30",
  "deadlineDateTime": "2025-01-06T14:30:00Z"
}
```

---

## 🎯 Hình ảnh / Giao diện

### Home Screen:
- Hiển thị sự kiện và nhiệm vụ với **ngày giờ chính xác**
- Ví dụ: `Monday, 06/01/2025 · 14:30` (sự kiện)

### Schedule Screen:
- Calendar hiển thị các sự kiện
- Click vào sự kiện để xem **chi tiết đầy đủ** (ngày, giờ, màu, icon)

### Dialog Chi tiết:
- ✅ Hiển thị **Ngày**: 06/01/2025
- ✅ Hiển thị **Giờ**: 14:30
- ✅ Hiển thị **Màu** (ở dạng hình tròn)
- ✅ Cho Sự kiện: hiển thị **Icon**

---

## 🚀 Cách sử dụng

### Thêm Sự kiện:
1. Nhấn nút **"+ Sự kiện"** (Home Screen)
2. Nhập **Tên sự kiện**
3. Chọn **Ngày** → **Giờ**
4. Chọn **Màu** & **Biểu tượng**
5. Nhấn **"Lưu"**

→ Sẽ nhận thông báo **15 phút trước** và **khi đến giờ**

### Thêm Nhiệm vụ:
1. Nhấn nút **"+ Nhiệm vụ"** (Home Screen)
2. Nhập **Tên nhiệm vụ**
3. Chọn **Ngày deadline** → **Giờ deadline**
4. Nhấn **"Lưu"**

→ Sẽ nhận thông báo **15 phút trước** và **khi đến deadline**

---

## 🔧 Kỹ thuật

### Files thay đổi:
- `lib/home_screen.dart` - Event & Task models, Notifications, Dialogs
- `lib/schedule_screen.dart` - Calendar display, Event details

### Dependencies:
- `firebase_core`
- `cloud_firestore`
- `flutter_local_notifications`
- `intl`
- `table_calendar`

### Migration Notes:
⚠️ **LƯU Ý**: Dữ liệu cũ (`time` và `date` tách rời) sẽ cần migrate lên `dateTime` đơn nhất.

---

## ✅ Testing

1. **Thêm sự kiện/nhiệm vụ** với ngày/giờ trong vòng 15 phút
2. **Đợi thông báo** xuất hiện trên màn hình
3. **Kiểm tra** Firestore có dữ liệu `dateTime` mới
4. **Chỉnh sửa** sự kiện/nhiệm vụ để thay đổi ngày giờ
5. **Xóa** sự kiện/nhiệm vụ từ các dialogs

---

## 📌 Ghi chú

- Thông báo sẽ chỉ hiển thị **1 lần** cho mỗi sự kiện/nhiệm vụ (dùng Set để lưu đã thông báo)
- Nếu app bị đóng, thông báo sẽ được kiểm tra lại khi mở app
- Kiểm tra mỗi **1 phút** tự động (Background)

---

**Phiên bản**: 2.0 - Thêm thời gian chính xác & thông báo đẩy
