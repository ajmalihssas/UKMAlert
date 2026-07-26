import 'package:cloud_firestore/cloud_firestore.dart';

// Firestore collection: laporan_kecemasan
class IncidentModel {
  final String id;
  final String category;    // jenisInsiden
  final String priority;
  final String description; // keterangan
  final double latitude;
  final double longitude;   // stored in lokasi GeoPoint
  final DateTime timestamp; // tarikhMasa
  final String status;      // statusLaporan: pending, received, responding, resolved
  final String userId;      // noMatriks / uid
  final String userEmail;
  final String locationName; // alamat
  final String notes;
  final String mediaUrl;
  final String mapsUrl;     // clickable Google Maps link

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
  });

  static String generateMapsUrl(double lat, double lng) =>
      'https://www.google.com/maps?q=$lat,$lng';

  factory IncidentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    double lat = 2.9277;
    double lng = 101.7809;

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
    );
  }

  Map<String, dynamic> toFirestore() {
    final url = mapsUrl.isNotEmpty ? mapsUrl : generateMapsUrl(latitude, longitude);
    return {
      'jenisInsiden': category,
      'priority': priority,
      'keterangan': description,
      'lokasi': GeoPoint(latitude, longitude),
      'alamat': locationName,
      'tarikhMasa': Timestamp.fromDate(timestamp),
      'statusLaporan': status,
      'noMatriks': userId,
      'userEmail': userEmail,
      'notes': notes,
      'mediaUrl': mediaUrl,
      'mapsUrl': url,
      'koordinat': '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
    };
  }

  IncidentModel copyWith({String? status, String? notes}) {
    return IncidentModel(
      id: id,
      category: category,
      priority: priority,
      description: description,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      status: status ?? this.status,
      userId: userId,
      userEmail: userEmail,
      locationName: locationName,
      notes: notes ?? this.notes,
      mediaUrl: mediaUrl,
      mapsUrl: mapsUrl,
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
