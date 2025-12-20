# Hướng dẫn cấu hình Firebase

## Bước 1: Tạo Firebase Project

1. Truy cập [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" hoặc chọn project có sẵn
3. Làm theo hướng dẫn để tạo project mới

## Bước 2: Thêm Android App vào Firebase

1. Trong Firebase Console, click vào biểu tượng Android
2. Nhập package name: `com.example.datbdd` (hoặc package name của bạn)
3. Download file `google-services.json`
4. Đặt file `google-services.json` vào thư mục `android/app/`

## Bước 3: Cấu hình Android

1. Mở file `android/build.gradle` (project level)
2. Thêm vào `dependencies`:
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
}
```

3. Mở file `android/app/build.gradle` (app level)
4. Thêm vào cuối file:
```gradle
apply plugin: 'com.google.gms.google-services'
```

## Bước 4: Cấu hình Firestore Database

1. Trong Firebase Console, vào **Firestore Database**
2. Click "Create database"
3. Chọn "Start in test mode" (cho development)
4. Chọn location gần bạn nhất
5. Click "Enable"

## Bước 5: Cài đặt dependencies

Chạy lệnh:
```bash
flutter pub get
```

## Bước 6: Chạy app

```bash
flutter run
```

## Lưu ý quan trọng

- **Test mode**: Firestore đang ở chế độ test, cho phép đọc/ghi trong 30 ngày
- **Security Rules**: Sau 30 ngày, bạn cần cấu hình Security Rules trong Firestore
- **Production**: Khi deploy production, nên cấu hình Security Rules để bảo mật dữ liệu

## Security Rules mẫu (cho production)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Cho phép đọc/ghi cho tất cả (chỉ dùng cho development)
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2024, 12, 31);
    }
    
    // Hoặc chỉ cho phép user đã đăng nhập (nếu có authentication)
    // match /events/{eventId} {
    //   allow read, write: if request.auth != null;
    // }
    // match /tasks/{taskId} {
    //   allow read, write: if request.auth != null;
    // }
  }
}
```

## Cấu trúc dữ liệu trong Firestore

### Collection: `events`
```json
{
  "title": "Meeting",
  "time": "10:00 AM - 11:00 AM",
  "date": Timestamp,
  "iconCodePoint": 59530,
  "iconFontFamily": null,
  "iconFontPackage": null,
  "colorValue": 4278190335
}
```

### Collection: `tasks`
```json
{
  "title": "Complete project",
  "deadline": "Hạn chót: 25/12/2024"
}
```

## Troubleshooting

### Lỗi: "FirebaseApp not initialized"
- Đảm bảo đã thêm `google-services.json` vào `android/app/`
- Đảm bảo đã apply plugin `com.google.gms.google-services` trong `build.gradle`

### Lỗi: "Permission denied"
- Kiểm tra Firestore Security Rules
- Đảm bảo database đang ở chế độ test mode hoặc có rules phù hợp

### Lỗi: "PlatformException"
- Chạy `flutter clean` và rebuild app hoàn toàn
- Đảm bảo đã cài đặt đầy đủ dependencies

