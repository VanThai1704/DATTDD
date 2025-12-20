# Hướng dẫn chi tiết cấu hình Firebase

## 📍 Bước 1: Tạo Firestore Database trong Firebase Console

1. **Truy cập Firebase Console:**
   - Vào: https://console.firebase.google.com/
   - Đăng nhập bằng tài khoản Google

2. **Tạo hoặc chọn Project:**
   - Nếu chưa có: Click **"Add project"** → Đặt tên → Tiếp tục
   - Nếu đã có: Chọn project từ danh sách

3. **Tạo Firestore Database:**
   - Trong menu bên trái, tìm và click **"Firestore Database"**
     - Hoặc: **"Build"** → **"Firestore Database"**
   - Click nút **"Create database"**
   - Chọn **"Start in test mode"** (cho development)
   - Chọn **Location** (ví dụ: `asia-southeast1` - Singapore)
   - Click **"Enable"**

## 📱 Bước 2: Thêm Android App vào Firebase

1. **Trong Firebase Console:**
   - Ở trang tổng quan project, click biểu tượng **Android** (hoặc **"Add app"** → chọn Android)

2. **Nhập thông tin:**
   - **Android package name:** `com.example.datbdd`
   - **App nickname:** (tùy chọn)
   - **Debug signing certificate SHA-1:** (bỏ qua nếu chưa có)

3. **Download file cấu hình:**
   - Click **"Download google-services.json"**
   - **Đặt file này vào:** `android/app/google-services.json`

## ⚙️ Bước 3: Cấu hình Android (Đã được tự động cập nhật)

Các file đã được cập nhật:
- ✅ `android/settings.gradle.kts` - Đã thêm Google Services plugin
- ✅ `android/app/build.gradle.kts` - Đã apply Google Services plugin

## 📦 Bước 4: Cài đặt dependencies

Chạy lệnh:
```bash
flutter pub get
```

## 🚀 Bước 5: Chạy app

```bash
flutter run
```

## ✅ Kiểm tra

Sau khi chạy app:
1. Thêm một sự kiện hoặc nhiệm vụ mới
2. Vào Firebase Console → Firestore Database
3. Bạn sẽ thấy 2 collections: `events` và `tasks`
4. Dữ liệu sẽ tự động sync real-time

## 🔒 Lưu ý bảo mật

- **Test mode** cho phép đọc/ghi trong 30 ngày
- Sau 30 ngày, cần cấu hình Security Rules trong Firestore
- Vào Firestore → Rules để cấu hình

## 🆘 Troubleshooting

### Lỗi: "FirebaseApp not initialized"
- Kiểm tra file `google-services.json` đã đặt đúng `android/app/`
- Chạy `flutter clean` và rebuild

### Lỗi: "Permission denied"
- Kiểm tra Firestore đang ở chế độ test mode
- Vào Firestore → Rules và đảm bảo có rule cho phép đọc/ghi

### Lỗi: "PlatformException"
- Chạy `flutter clean`
- Xóa thư mục `build/` và `.dart_tool/`
- Chạy lại `flutter pub get` và `flutter run`

