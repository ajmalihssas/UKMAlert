import 'package:cloud_firestore/cloud_firestore.dart';

class SafetyContentModel {
  final String id;
  final String title;
  final String content;
  final String category; // 'sop', 'guideline', 'info'
  final DateTime updatedAt;

  SafetyContentModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.updatedAt,
  });

  factory SafetyContentModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return SafetyContentModel(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] ?? 'info',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'category': category,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
