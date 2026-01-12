// Import các thư viện cần thiết
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Mức độ ưu tiên của nhiệm vụ
enum TaskPriority { 
  low,    // Thấp
  medium, // Trung bình
  high    // Cao
}

/// Loại lặp lại của nhiệm vụ
enum RecurringType { 
  none,    // Không lặp lại
  daily,   // Hàng ngày
  weekly,  // Hàng tuần
  monthly  // Hàng tháng
}

/// Mục trong checklist (danh sách công việc con)
class ChecklistItem {
  String title;  // Tiêu đề công việc con
  bool isDone;   // Đã hoàn thành chưa
  
  ChecklistItem({required this.title, this.isDone = false});

  /// Chuyển đổi thành JSON để lưu vào Firebase
  Map<String, dynamic> toJson() => {'title': title, 'isDone': isDone};
  
  /// Tạo từ JSON lấy từ Firebase
  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    title: json['title'] ?? '',
    isDone: json['isDone'] ?? false,
  );
}

/// Dự án - dùng để nhóm các nhiệm vụ lại với nhau
class Project {
  final String? id;       // ID trong Firebase
  final String name;      // Tên dự án
  final int colorValue;   // Màu sắc đại diện (dạng số)

  Project({this.id, required this.name, required this.colorValue});

  /// Chuyển đổi thành JSON để lưu vào Firebase
  Map<String, dynamic> toJson() => {'name': name, 'colorValue': colorValue};
  
  /// Tạo từ dữ liệu Firestore
  factory Project.fromFirestore(Map<String, dynamic> data, String id) =>
      Project(
        id: id,
        name: data['name'] ?? '',
        colorValue: data['colorValue'] ?? Colors.blue.value,
      );
}

/// Thống kê người dùng
class UserStats {
  final int coins;                // Số tiền xu kiếm được
  final int streakFreezes;        // Số lần đông băng streak còn lại
  final int currentStreak;        // Chuỗi ngày liên tục hiện tại
  final DateTime? lastStreakDate; // Ngày cuối cùng có hoạt động

  UserStats({
    this.coins = 0,
    this.streakFreezes = 0,
    this.currentStreak = 0,
    this.lastStreakDate,
  });

  /// Chuyển đổi thành JSON để lưu vào Firebase
  Map<String, dynamic> toJson() => {
    'coins': coins,
    'streakFreezes': streakFreezes,
    'currentStreak': currentStreak,
    'lastStreakDate': lastStreakDate != null
        ? Timestamp.fromDate(lastStreakDate!)
        : null,
  };

  /// Tạo từ dữ liệu Firestore
  factory UserStats.fromFirestore(Map<String, dynamic> data) => UserStats(
    coins: data['coins'] ?? 0,
    streakFreezes: data['streakFreezes'] ?? 0,
    currentStreak: data['currentStreak'] ?? 0,
    lastStreakDate: (data['lastStreakDate'] as Timestamp?)?.toDate(),
  );
}

/// Nhiệm vụ (Task) - class chính của ứng dụng
class Task {
  final String? id;                         // ID trong Firebase
  final String title;                       // Tiêu đề nhiệm vụ
  final String description;                 // Mô tả chi tiết
  final DateTime deadlineDateTime;          // Thời hạn (ngày + giờ)
  final int durationMinutes;                // Thời lượng ước tính (phút)
  final bool isCompleted;                   // Đã hoàn thành chưa
  final DateTime? completedAt;              // Thời điểm hoàn thành
  final TaskPriority priority;              // Mức độ ưu tiên
  final String? projectId;                  // ID dự án (nếu có)
  final List<ChecklistItem> checklist;      // Danh sách công việc con
  final RecurringType recurring;            // Loại lặp lại
  final List<String> tags;                  // Các thẻ tag

  Task({
    this.id,
    required this.title,
    this.description = '',
    required this.deadlineDateTime,
    this.durationMinutes = 30,
    this.isCompleted = false,
    this.completedAt,
    this.priority = TaskPriority.medium,
    this.projectId,
    this.checklist = const [],
    this.recurring = RecurringType.none,
    this.tags = const [],
  });

  /// Chuyển đổi thành JSON để lưu vào Firebase
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'deadlineDateTime': Timestamp.fromDate(deadlineDateTime), // Lưu dạng Timestamp
    'durationMinutes': durationMinutes,
    'isCompleted': isCompleted,
    'completedAt': completedAt != null
        ? Timestamp.fromDate(completedAt!)
        : null,
    'priority': priority.index, // Lưu dạng số (0,1,2)
    'projectId': projectId,
    'checklist': checklist.map((e) => e.toJson()).toList(),
    'recurring': recurring.index, // Lưu dạng số (0,1,2,3)
    'tags': tags,
  };

  /// Tạo Task từ dữ liệu Firestore
  factory Task.fromFirestore(Map<String, dynamic> data, String id) => Task(
    id: id,
    title: data['title'] ?? '',
    description: data['description'] ?? '',
    deadlineDateTime: (data['deadlineDateTime'] as Timestamp).toDate(),
    durationMinutes: data['durationMinutes'] ?? 30,
    isCompleted: data['isCompleted'] ?? false,
    completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    priority: TaskPriority.values[data['priority'] ?? 1], // Chuyển số thành enum
    projectId: data['projectId'],
    checklist: (data['checklist'] as List? ?? [])
        .map((e) => ChecklistItem.fromJson(e))
        .toList(),
    recurring: RecurringType.values[data['recurring'] ?? 0], // Chuyển số thành enum
    tags: List<String>.from(data['tags'] ?? []),
  );

  /// Tạo bản sao cụa Task với một số thuộc tính thay đổi
  /// Hữu ích khi cần cập nhật một vài trường mà giữ nguyên các trường khác
  Task copyWith({
    String? id,
    bool? isCompleted,
    DateTime? completedAt,
    List<ChecklistItem>? checklist,
    DateTime? deadlineDateTime,
  }) {
    return Task(
      id: id ?? this.id,
      title: title,
      description: description,
      deadlineDateTime: deadlineDateTime ?? this.deadlineDateTime,
      durationMinutes: durationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      priority: priority,
      projectId: projectId,
      checklist: checklist ?? this.checklist,
      recurring: recurring,
      tags: tags,
    );
  }
}
