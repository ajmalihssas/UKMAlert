import 'package:cloud_firestore/cloud_firestore.dart';

class IncidentModel {
  final String id;
  final String category;
  final String priority;
  final String description;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String status;
  final String userId;
  final String userEmail;
  final String locationName;
  final String notes;
  final String mediaUrl;
  final String mapsUrl;
  final String koordinat;

  static const String collection = 'laporan_kecemasan';

  IncidentModel({
    required this.id,
    required this.category,
    required this.priority,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.status = 'pending',
    this.userId = '',
    this.userEmail = '',
    this.locationName = '',
    this.notes = '',
    this.mediaUrl = '',
    this.mapsUrl = '',
    this.koordinat = '',
  });

  static String generateMapsUrl(double lat, double lng) =>
      'https://www.google.com/maps?q=$lat,$lng';

  factory IncidentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    double lat = 2.9277, lng = 101.7809;
    if (data['lokasi'] is GeoPoint) {
      final gp = data['lokasi'] as GeoPoint;
      lat = gp.latitude;
      lng = gp.longitude;
    } else {
      lat = (data['latitude'] ?? data['lat'] ?? 2.9277).toDouble();
      lng = (data['longitude'] ?? data['lng'] ?? 101.7809).toDouble();
    }
    return IncidentModel(
      id: doc.id,
      category: data['jenisInsiden'] ?? data['category'] ?? '',
      priority: data['priority'] ?? '',
      description: data['keterangan'] ?? data['description'] ?? '',
      latitude: lat,
      longitude: lng,
      timestamp: (data['tarikhMasa'] as Timestamp?)?.toDate() ??
          (data['timestamp'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      status: data['statusLaporan'] ?? data['status'] ?? 'pending',
      userId: data['noMatriks'] ?? data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      locationName: data['alamat'] ?? data['locationName'] ?? '',
      notes: data['notes'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      mapsUrl: data['mapsUrl'] ?? generateMapsUrl(lat, lng),
      koordinat: data['koordinat'] ?? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
    );
  }

  static String statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'resolved':   return 'Selesai';
      case 'responding': return 'Bantuan Dalam Perjalanan';
      case 'received':   return 'Diterima';
      default:           return 'Menunggu';
    }
  }
}
