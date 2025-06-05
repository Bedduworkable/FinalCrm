import 'package:cloud_firestore/cloud_firestore.dart';

class Lead {
  final String id;
  final String name;
  final String mobile;
  final String email;
  final String status;
  final List<String> projects;
  final List<String> sources;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;

  Lead({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    required this.status,
    required this.projects,
    required this.sources,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
  });

  factory Lead.fromMap(Map<String, dynamic> map, String id) {
    return Lead(
      id: id,
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      email: map['email'] ?? '',
      status: map['status'] ?? 'New',
      projects: List<String>.from(map['projects'] ?? []),
      sources: List<String>.from(map['sources'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mobile': mobile,
      'email': email,
      'status': status,
      'projects': projects,
      'sources': sources,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'userId': userId,
    };
  }

  Lead copyWith({
    String? name,
    String? mobile,
    String? email,
    String? status,
    List<String>? projects,
    List<String>? sources,
    DateTime? updatedAt,
  }) {
    return Lead(
      id: id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      status: status ?? this.status,
      projects: projects ?? this.projects,
      sources: sources ?? this.sources,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      userId: userId,
    );
  }
}

class Remark {
  final String id;
  final String leadId;
  final String content;
  final RemarkType type;
  final DateTime createdAt;
  final String userId;
  final Map<String, dynamic>? metadata;

  Remark({
    required this.id,
    required this.leadId,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.userId,
    this.metadata,
  });

  factory Remark.fromMap(Map<String, dynamic> map, String id) {
    return Remark(
      id: id,
      leadId: map['leadId'] ?? '',
      content: map['content'] ?? '',
      type: RemarkType.values.firstWhere(
            (e) => e.toString() == map['type'],
        orElse: () => RemarkType.note,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: map['userId'] ?? '',
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leadId': leadId,
      'content': content,
      'type': type.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'metadata': metadata,
    };
  }
}

enum RemarkType {
  note,
  followUpSet,
  followUpSnoozed,
  followUpCompleted,
  statusChanged,
  leadCreated,
}

class FollowUp {
  final String id;
  final String leadId;
  final DateTime scheduledAt;
  final String title;
  final String? description;
  final FollowUpStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? completionNote;
  final String userId;

  FollowUp({
    required this.id,
    required this.leadId,
    required this.scheduledAt,
    required this.title,
    this.description,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.completionNote,
    required this.userId,
  });

  factory FollowUp.fromMap(Map<String, dynamic> map, String id) {
    return FollowUp(
      id: id,
      leadId: map['leadId'] ?? '',
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      title: map['title'] ?? '',
      description: map['description'],
      status: FollowUpStatus.values.firstWhere(
            (e) => e.toString() == map['status'],
        orElse: () => FollowUpStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      completionNote: map['completionNote'],
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leadId': leadId,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'title': title,
      'description': description,
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'completionNote': completionNote,
      'userId': userId,
    };
  }

  FollowUp copyWith({
    DateTime? scheduledAt,
    String? title,
    String? description,
    FollowUpStatus? status,
    DateTime? completedAt,
    String? completionNote,
  }) {
    return FollowUp(
      id: id,
      leadId: leadId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      completionNote: completionNote ?? this.completionNote,
      userId: userId,
    );
  }

  bool get isOverdue =>
      status == FollowUpStatus.pending &&
          scheduledAt.isBefore(DateTime.now());

  bool get isDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduleDate = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    return scheduleDate == today && status == FollowUpStatus.pending;
  }

  bool get isDueSoon {
    final now = DateTime.now();
    final difference = scheduledAt.difference(now).inHours;
    return difference <= 2 && difference >= 0 && status == FollowUpStatus.pending;
  }
}

enum FollowUpStatus {
  pending,
  completed,
  snoozed,
  cancelled,
}

// Extension methods for easy status management
extension FollowUpStatusExtension on FollowUpStatus {
  String get displayName {
    switch (this) {
      case FollowUpStatus.pending:
        return 'Pending';
      case FollowUpStatus.completed:
        return 'Completed';
      case FollowUpStatus.snoozed:
        return 'Snoozed';
      case FollowUpStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive => this == FollowUpStatus.pending;
}

extension RemarkTypeExtension on RemarkType {
  String get displayName {
    switch (this) {
      case RemarkType.note:
        return 'Note';
      case RemarkType.followUpSet:
        return 'Follow-up Set';
      case RemarkType.followUpSnoozed:
        return 'Follow-up Snoozed';
      case RemarkType.followUpCompleted:
        return 'Follow-up Completed';
      case RemarkType.statusChanged:
        return 'Status Changed';
      case RemarkType.leadCreated:
        return 'Lead Created';
    }
  }

  bool get isSystemGenerated {
    return this != RemarkType.note;
  }
}