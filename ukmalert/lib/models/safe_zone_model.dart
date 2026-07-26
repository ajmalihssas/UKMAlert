import 'package:cloud_firestore/cloud_firestore.dart';

class SafeZoneModel {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final double radius; // In meters
  final DateTime updatedAt;

  SafeZoneModel({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.updatedAt,
  });

  factory SafeZoneModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SafeZoneModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      radius: (data['radius'] ?? 100.0).toDouble(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
