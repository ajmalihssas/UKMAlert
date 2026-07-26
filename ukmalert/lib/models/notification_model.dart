import 'package:cloud_firestore/cloud_firestore.dart';

// Firestore collection: notifikasi
class NotificationModel {
  final String id;
  final String title;
  final String message;  // mesej
  final String type;     // 'emergency', 'update', 'campus'
  final DateTime timestamp; // tarikhHantar
  final bool isRead;    // status (boolean)
  final String targetUserId; // noMatriks — empty means broadcast

  static const String collection = 'notifikasi';

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.targetUserId = '',
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['mesej'] ?? data['message'] ?? '',
      type: data['type'] ?? 'update',
      timestamp: (data['tarikhHantar'] as Timestamp?)?.toDate() ??
          (data['timestamp'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      isRead: data['status'] is bool
          ? data['status'] as bool
          : (data['isRead'] ?? false) as bool,
      targetUserId: data['noMatriks'] ?? data['targetUserId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'mesej': message,
      'type': type,
      'tarikhHantar': Timestamp.fromDate(timestamp),
      'status': isRead,
      'noMatriks': targetUserId,
    };
  }
}
