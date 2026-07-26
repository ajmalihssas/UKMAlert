import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/incident_model.dart';

/// Manages offline SOS queue.
///
/// When no internet is available, SOS incidents are serialised to
/// SharedPreferences. Any device (originator or ad-hoc relay receiver) that
/// later has internet calls [uploadPendingQueue] to flush them to Firestore.
class SosQueueService {
  static final SosQueueService _instance = SosQueueService._();
  factory SosQueueService() => _instance;
  SosQueueService._();

  static const _queueKey = 'sos_offline_queue';

  // ── Internet check ────────────────────────────────────────────────────────

  static Future<bool> hasInternet() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Queue management ──────────────────────────────────────────────────────

  /// Serialise [incident] to the local queue.
  /// Uses plain lat/lng + ISO-8601 so SharedPreferences can store it.
  Future<void> queueSOS(IncidentModel incident) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];

    final entry = jsonEncode({
      'jenisInsiden': incident.category,
      'priority': incident.priority,
      'keterangan': incident.description,
      'latitude': incident.latitude,
      'longitude': incident.longitude,
      'alamat': incident.locationName,
      'tarikhMasa': incident.timestamp.toIso8601String(),
      'statusLaporan': incident.status,
      'noMatriks': incident.userId,
      'userEmail': incident.userEmail,
      'notes': incident.notes,
      'mediaUrl': incident.mediaUrl,
      'mapsUrl': incident.mapsUrl,
      'koordinat':
          '${incident.latitude.toStringAsFixed(6)}, ${incident.longitude.toStringAsFixed(6)}',
    });

    queue.add(entry);
    await prefs.setStringList(_queueKey, queue);
    debugPrint('[SosQueue] Queued. Total pending: ${queue.length}');
  }

  /// Add a raw map (received via ad-hoc relay) to the queue.
  /// Deduplicates by mapsUrl + tarikhMasa combination.
  Future<void> queueRaw(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    final entry = jsonEncode(data);
    if (!queue.contains(entry)) {
      queue.add(entry);
      await prefs.setStringList(_queueKey, queue);
      debugPrint('[SosQueue] Relay queued. Total pending: ${queue.length}');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_queueKey) ?? [])
        .map((e) => Map<String, dynamic>.from(jsonDecode(e) as Map))
        .toList();
  }

  Future<bool> hasPending() async =>
      (await getPendingQueue()).isNotEmpty;

  // ── Upload ────────────────────────────────────────────────────────────────

  /// Upload every pending SOS to Firebase and remove successful entries.
  /// Safe to call repeatedly; silently skips if offline.
  Future<int> uploadPendingQueue() async {
    if (!(await hasInternet())) return 0;

    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    if (queue.isEmpty) return 0;

    int uploaded = 0;
    final remaining = <String>[];

    for (final entry in queue) {
      try {
        final raw = Map<String, dynamic>.from(jsonDecode(entry) as Map);

        // Re-hydrate Firestore types
        final lat = (raw['latitude'] as num?)?.toDouble() ?? 2.9277;
        final lng = (raw['longitude'] as num?)?.toDouble() ?? 101.7809;
        final ts = raw['tarikhMasa'] != null
            ? Timestamp.fromDate(DateTime.parse(raw['tarikhMasa'] as String))
            : Timestamp.now();

        final firestoreDoc = {
          'jenisInsiden': raw['jenisInsiden'] ?? 'SOS',
          'priority': raw['priority'] ?? 'TINGGI',
          'keterangan': raw['keterangan'] ?? '',
          'lokasi': GeoPoint(lat, lng),
          'alamat': raw['alamat'] ?? '',
          'tarikhMasa': ts,
          'statusLaporan': raw['statusLaporan'] ?? 'pending',
          'noMatriks': raw['noMatriks'] ?? '',
          'userEmail': raw['userEmail'] ?? '',
          'notes': raw['notes'] ?? '',
          'mediaUrl': raw['mediaUrl'] ?? '',
          'mapsUrl': raw['mapsUrl'] ?? IncidentModel.generateMapsUrl(lat, lng),
          'koordinat': raw['koordinat'] ??
              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
          'viaAdhoc': raw['viaAdhoc'] ?? false,
        };

        await FirebaseFirestore.instance
            .collection(IncidentModel.collection)
            .add(firestoreDoc);

        uploaded++;
        debugPrint('[SosQueue] Uploaded 1 entry to Firebase.');
      } catch (e) {
        debugPrint('[SosQueue] Upload failed: $e');
        remaining.add(entry);
      }
    }

    await prefs.setStringList(_queueKey, remaining);
    debugPrint(
        '[SosQueue] Flush done: $uploaded uploaded, ${remaining.length} remaining.');
    return uploaded;
  }

  // ── Encode / decode for ad-hoc wire format ────────────────────────────────

  /// Encode [incident] as a base-64 string for transmission over ad-hoc mesh.
  static String encodeForRelay(IncidentModel incident) {
    final map = {
      'jenisInsiden': incident.category,
      'priority': incident.priority,
      'keterangan': incident.description,
      'latitude': incident.latitude,
      'longitude': incident.longitude,
      'alamat': incident.locationName,
      'tarikhMasa': incident.timestamp.toIso8601String(),
      'statusLaporan': incident.status,
      'noMatriks': incident.userId,
      'userEmail': incident.userEmail,
      'notes': incident.notes,
      'mediaUrl': incident.mediaUrl,
      'mapsUrl': incident.mapsUrl,
      'koordinat':
          '${incident.latitude.toStringAsFixed(6)}, ${incident.longitude.toStringAsFixed(6)}',
      'viaAdhoc': true,
    };
    return base64Encode(utf8.encode(jsonEncode(map)));
  }

  /// Encode a raw map (from the local queue) for ad-hoc relay.
  static String encodeForRelayMap(Map<String, dynamic> data) =>
      base64Encode(utf8.encode(jsonEncode(data)));

  /// Decode a base-64 relay payload. Returns null if invalid.
  static Map<String, dynamic>? decodeRelay(String encoded) {
    try {
      final json = utf8.decode(base64Decode(encoded));
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (_) {
      return null;
    }
  }
}
