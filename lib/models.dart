import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum TaskPriority { low, medium, high }

class ChecklistItem {
  String title;
  bool isDone;
  ChecklistItem({required this.title, this.isDone = false});

  Map<String, dynamic> toJson() => {'title': title, 'isDone': isDone};
  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    title: json['title'] ?? '',
    isDone: json['isDone'] ?? false,
  );
}

class Project {
  final String? id;
  final String name;
  final int colorValue;

  Project({this.id, required this.name, required this.colorValue});

  Map<String, dynamic> toJson() => {'name': name, 'colorValue': colorValue};
  factory Project.fromFirestore(Map<String, dynamic> data, String id) =>
      Project(
        id: id,
        name: data['name'] ?? '',
        colorValue: data['colorValue'] ?? Colors.blue.value,
      );
}

class UserStats {
  final int coins;
  final int streakFreezes;
  final int currentStreak;
  final DateTime? lastStreakDate;

  UserStats({
    this.coins = 0,
    this.streakFreezes = 0,
    this.currentStreak = 0,
    this.lastStreakDate,
  });

  Map<String, dynamic> toJson() => {
    'coins': coins,
    'streakFreezes': streakFreezes,
    'currentStreak': currentStreak,
    'lastStreakDate': lastStreakDate != null
        ? Timestamp.fromDate(lastStreakDate!)
        : null,
  };

  factory UserStats.fromFirestore(Map<String, dynamic> data) => UserStats(
    coins: data['coins'] ?? 0,
    streakFreezes: data['streakFreezes'] ?? 0,
    currentStreak: data['currentStreak'] ?? 0,
    lastStreakDate: (data['lastStreakDate'] as Timestamp?)?.toDate(),
  );
}

class Task {
  final String? id;
  final String title;
  final String description;
  final DateTime deadlineDateTime;
  final int durationMinutes;
  final bool isCompleted;
  final DateTime? completedAt;
  final TaskPriority priority;
  final String? projectId;
  final List<ChecklistItem> checklist;

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
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'deadlineDateTime': Timestamp.fromDate(deadlineDateTime),
    'durationMinutes': durationMinutes,
    'isCompleted': isCompleted,
    'completedAt': completedAt != null
        ? Timestamp.fromDate(completedAt!)
        : null,
    'priority': priority.index,
    'projectId': projectId,
    'checklist': checklist.map((e) => e.toJson()).toList(),
  };

  factory Task.fromFirestore(Map<String, dynamic> data, String id) => Task(
    id: id,
    title: data['title'] ?? '',
    description: data['description'] ?? '',
    deadlineDateTime: (data['deadlineDateTime'] as Timestamp).toDate(),
    durationMinutes: data['durationMinutes'] ?? 30,
    isCompleted: data['isCompleted'] ?? false,
    completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    priority: TaskPriority.values[data['priority'] ?? 1],
    projectId: data['projectId'],
    checklist: (data['checklist'] as List? ?? [])
        .map((e) => ChecklistItem.fromJson(e))
        .toList(),
  );

  Task copyWith({
    String? id,
    bool? isCompleted,
    DateTime? completedAt,
    List<ChecklistItem>? checklist,
  }) {
    return Task(
      id: id ?? this.id,
      title: title,
      description: description,
      deadlineDateTime: deadlineDateTime,
      durationMinutes: durationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      priority: priority,
      projectId: projectId,
      checklist: checklist ?? this.checklist,
    );
  }
}
