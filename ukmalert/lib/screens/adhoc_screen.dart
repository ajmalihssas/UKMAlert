import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/sos_queue_service.dart';
import '../models/incident_model.dart';
import '../providers/user_provider.dart';

/// KF4: Penghantaran Mesej Secara Berperingkat Melalui Rangkaian Ad Hoc
/// Uses Google Nearby Connections API (Wi-Fi Direct + Bluetooth Mesh)
class AdhocScreen extends StatefulWidget {
  const AdhocScreen({super.key});
  @override
  State<AdhocScreen> createState() => _AdhocScreenState();
}

class _MessageLog {
  final String message;
  final DateTime timestamp;
  final bool isIncoming;
  String status; // 'sending', 'delivered', 'received'
  _MessageLog({
    required this.message,
    required this.timestamp,
    required this.isIncoming,
  }) : status = isIncoming ? 'received' : 'sending';
}

class _AdhocScreenState extends State<AdhocScreen> with TickerProviderStateMixin {
  bool _isScanning = false;
  bool _isReady = false;
  bool _permissionDenied = false;
  String _statusText = 'Memulakan mod rangkaian Ad Hoc...';

  // endpointId -> display name
  final Map<String, String> _discoveredEndpoints = {};
  final Map<String, String> _connectedEndpoints = {};

  // Message deduplication — prevents relay loops in the mesh
  final Set<String> _seenMessageIds = {};

  static const _sosRelayPrefix = 'SOS_RELAY:';

  final _messageController = TextEditingController();
  final List<_MessageLog> _messageLogs = [];
  late AnimationController _radarController;

  static const String _serviceId = 'com.example.ukmalert.adhoc';
  late final String _myId;

  bool get _isConnected => _connectedEndpoints.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _myId = 'UKM-${DateTime.now().millisecondsSinceEpoch % 100000}';
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _initNearby();
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      Nearby().stopAllEndpoints();
      Nearby().stopAdvertising();
      Nearby().stopDiscovery();
    }
    _messageController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  /// This screen is reachable directly from the login screen (offline
  /// emergency mode), so there may be no authenticated user yet. Firestore
  /// rules require `request.auth != null` for all reads/writes, so without
  /// this every hop log and relayed SOS report is silently rejected.
  Future<void> _ensureSignedIn() async {
    if (FirebaseAuth.instance.currentUser != null) return;
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('Adhoc anonymous sign-in error: $e');
    }
  }

  Future<void> _initNearby() async {
    if (kIsWeb) {
      setState(() => _statusText = 'Rangkaian Ad Hoc tidak disokong pada web.');
      return;
    }
    await _ensureSignedIn();
    final ok = await _requestPermissions();
    if (!ok) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _statusText = 'Kebenaran lokasi dan Bluetooth diperlukan untuk mod Ad Hoc.';
        });
      }
      return;
    }
    await _startAdvertising();
  }

  /// Requests all permissions required by Google Nearby Connections.
  ///
  /// On Android 12+ BLUETOOTH_SCAN / CONNECT / ADVERTISE are runtime permissions.
  /// permission_handler auto-grants them on older Android where they don't exist,
  /// so checking them unconditionally is safe across all API levels.
  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.nearbyWifiDevices, // Android 13+
    ].request();

    final locationOk =
        statuses[Permission.location] == PermissionStatus.granted;
    final btScanOk =
        statuses[Permission.bluetoothScan] == PermissionStatus.granted;
    final btConnectOk =
        statuses[Permission.bluetoothConnect] == PermissionStatus.granted;
    final btAdvertiseOk =
        statuses[Permission.bluetoothAdvertise] == PermissionStatus.granted;

    // All four must be granted for Nearby Connections to function on Android 12+.
    // On Android 11 and below, permission_handler returns PermissionStatus.granted
    // automatically for BT runtime permissions that don't exist on that API level.
    return locationOk && btScanOk && btConnectOk && btAdvertiseOk;
  }

  // ── Firestore hop-logging ─────────────────────────────────────────────────
  Future<void> _logHop({
    required String action,
    required String peerName,
    String? message,
    bool incoming = false,
  }) async {
    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 3)),
        );
      } catch (_) {}

      await FirebaseFirestore.instance.collection('adhoc_logs').add({
        'fromDevice': incoming ? peerName : _myId,
        'toDevice': incoming ? _myId : peerName,
        'action': action,
        'message': message ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
        'mapsUrl': pos != null
            ? 'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}'
            : null,
      });
    } catch (e) {
      debugPrint('Adhoc log error: $e');
    }
  }

  // ── SOS relay ─────────────────────────────────────────────────────────────

  /// Called when a received message carries a SOS_RELAY payload.
  /// If internet is available the SOS is uploaded to Firebase immediately;
  /// otherwise it is saved to the local queue for later upload.
  Future<void> _handleSosRelay(String content, String senderId) async {
    final encoded = content.substring(_sosRelayPrefix.length);
    final data = SosQueueService.decodeRelay(encoded);
    if (data == null) return;

    final peerName = _connectedEndpoints[senderId] ??
        _discoveredEndpoints[senderId] ??
        senderId;
    final desc = (data['keterangan'] as String?)?.trim().isNotEmpty == true
        ? data['keterangan'] as String
        : 'SOS Kecemasan';

    debugPrint('[AdHoc] SOS relay received from $peerName.');

    if (mounted) {
      setState(() {
        _messageLogs.add(_MessageLog(
          message: desc,
          timestamp: DateTime.now(),
          isIncoming: true,
        ));
      });
    }

    bool uploadedDirectly = false;
    if (await SosQueueService.hasInternet()) {
      try {
        final ts = data['tarikhMasa'] != null
            ? Timestamp.fromDate(DateTime.parse(data['tarikhMasa'] as String))
            : Timestamp.now();
        await FirebaseFirestore.instance
            .collection(IncidentModel.collection)
            .add({
          'jenisInsiden': data['jenisInsiden'] ?? 'SOS',
          'priority': data['priority'] ?? 'TINGGI',
          'keterangan': desc,
          'lokasi': GeoPoint(
            (data['latitude'] as num?)?.toDouble() ?? 2.9277,
            (data['longitude'] as num?)?.toDouble() ?? 101.7809,
          ),
          'alamat': data['alamat'] ?? '',
          'tarikhMasa': ts,
          'statusLaporan': data['statusLaporan'] ?? 'pending',
          'noMatriks': data['noMatriks'] ?? '',
          'userEmail': data['userEmail'] ?? '',
          'notes': data['notes'] ?? '',
          'mediaUrl': data['mediaUrl'] ?? '',
          'mapsUrl': data['mapsUrl'] ?? '',
          'koordinat': data['koordinat'] ?? '',
          'viaAdhoc': true,
        });
        uploadedDirectly = true;
      } catch (e) {
        debugPrint('[AdHoc] SOS relay direct upload failed: $e');
      }

      // Also flush anything already queued (e.g. from an earlier hop).
      await SosQueueService().uploadPendingQueue();

      if (uploadedDirectly && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'SOS diterima via Ad Hoc — dihantar ke Firebase.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ));
      }
    } else {
      await SosQueueService().queueRaw(data);
      debugPrint('[AdHoc] SOS relay queued (no internet).');
    }

    _logHop(
      action: 'message_sent',
      peerName: peerName,
      message: desc,
      incoming: true,
    );
  }

  /// Broadcast every pending queued SOS to all currently connected peers.
  /// Called whenever a new peer connects so the SOS propagates toward a
  /// device that has internet access.
  Future<void> _broadcastQueuedSOS() async {
    if (_connectedEndpoints.isEmpty) return;
    final pending = await SosQueueService().getPendingQueue();
    if (pending.isEmpty) return;

    for (final data in pending) {
      // Try to upload directly first (this device may now have internet)
      if (await SosQueueService.hasInternet()) {
        await SosQueueService().uploadPendingQueue();
        return;
      }

      // No internet — encode and send to all connected peers
      final encoded = SosQueueService.encodeForRelayMap(data);
      final msgId =
          '${DateTime.now().millisecondsSinceEpoch}-${data.hashCode.abs()}';
      final rawPayload = '$msgId|$_sosRelayPrefix$encoded';
      _seenMessageIds.add(msgId);

      final bytes = Uint8List.fromList(rawPayload.codeUnits);
      for (final endpointId in List<String>.from(_connectedEndpoints.keys)) {
        Nearby()
            .sendBytesPayload(endpointId, bytes)
            .catchError((e) => debugPrint('SOS relay send error: $e'));
      }
      debugPrint('[AdHoc] Broadcasted queued SOS to ${_connectedEndpoints.length} peer(s).');
    }
  }

  Future<void> _startAdvertising() async {
    try {
      await Nearby().startAdvertising(
        _myId,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (id, status) {
          if (!mounted) return;
          if (status == Status.CONNECTED) {
            final peerName = _discoveredEndpoints[id] ?? id;
            setState(() {
              _connectedEndpoints[id] = peerName;
              _statusText = 'Disambungkan ke ${_connectedEndpoints.length} peranti';
            });
            _logHop(action: 'connected', peerName: peerName);
            _broadcastQueuedSOS();
          } else if (status == Status.ERROR || status == Status.REJECTED) {
            setState(() => _discoveredEndpoints.remove(id));
          }
        },
        onDisconnected: (id) {
          if (!mounted) return;
          final peerName = _connectedEndpoints[id] ?? id;
          _logHop(action: 'disconnected', peerName: peerName);
          setState(() {
            _connectedEndpoints.remove(id);
            _discoveredEndpoints.remove(id);
            _statusText = _connectedEndpoints.isEmpty
                ? 'Peranti terputus. Imbas semula untuk menyambung.'
                : 'Disambungkan ke ${_connectedEndpoints.length} peranti';
          });
        },
        serviceId: _serviceId,
      );
      if (mounted) {
        setState(() {
          _isReady = true;
          _statusText = 'Sedia — peranti lain boleh menemui anda';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Ralat permulaan: $e');
      }
    }
  }

  /// Called when either side initiates a connection.
  ///
  /// Auto-accepts in emergency context.  On payload receipt, the message is
  /// forwarded to every OTHER connected peer (multi-hop relay) before being
  /// displayed locally.  A seenMessageIds set prevents relay loops.
  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (id, payload) {
        if (payload.type == PayloadType.BYTES && payload.bytes != null) {
          final raw = String.fromCharCodes(payload.bytes!);

          // Wire format: "<msgId>|<content>"
          final sepIdx = raw.indexOf('|');
          final msgId = sepIdx > 0 ? raw.substring(0, sepIdx) : raw;
          final content = sepIdx > 0 ? raw.substring(sepIdx + 1) : raw;

          // Deduplication — drop if we've already processed this message ID
          if (_seenMessageIds.contains(msgId)) return;
          _seenMessageIds.add(msgId);

          // Multi-hop relay: forward to every peer except the sender
          final relayBytes = payload.bytes!;
          for (final otherId in List<String>.from(_connectedEndpoints.keys)) {
            if (otherId != id) {
              Nearby().sendBytesPayload(otherId, relayBytes).catchError(
                  (e) => debugPrint('Relay error to $otherId: $e'));
            }
          }

          // Only SOS relay payloads are expected on this channel.
          if (content.startsWith(_sosRelayPrefix)) {
            _handleSosRelay(content, id);
          } else {
            debugPrint('[AdHoc] Ignored non-SOS payload from $id.');
          }
        }
      },
      onPayloadTransferUpdate: (id, update) {},
    );
    if (mounted) setState(() => _discoveredEndpoints[endpointId] = info.endpointName);
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _discoveredEndpoints.clear();
      _statusText = 'Mengimbas peranti berdekatan...';
    });
    _radarController.repeat();

    try {
      await Nearby().startDiscovery(
        _myId,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (id, name, serviceId) {
          if (!mounted) return;
          setState(() => _discoveredEndpoints[id] = name);

          // Auto-connect to every discovered peer (mesh expansion)
          Nearby().requestConnection(
            _myId,
            id,
            onConnectionInitiated: _onConnectionInitiated,
            onConnectionResult: (endId, status) {
              if (!mounted) return;
              if (status == Status.CONNECTED) {
                final peerName = _discoveredEndpoints[endId] ?? endId;
                setState(() {
                  _connectedEndpoints[endId] = peerName;
                  // Keep _isScanning = true so we continue looking for more peers
                  _statusText =
                      'Disambungkan ke ${_connectedEndpoints.length} peranti — mengimbas lagi...';
                });
                _logHop(action: 'connected', peerName: peerName);
                _broadcastQueuedSOS();
                // Do NOT stop discovery here — mesh needs to keep expanding
              }
            },
            onDisconnected: (endId) {
              if (!mounted) return;
              final peerName = _connectedEndpoints[endId] ?? endId;
              _logHop(action: 'disconnected', peerName: peerName);
              setState(() {
                _connectedEndpoints.remove(endId);
                _discoveredEndpoints.remove(endId);
              });
            },
          );
        },
        onEndpointLost: (id) {
          if (mounted && id != null) {
            setState(() => _discoveredEndpoints.remove(id));
          }
        },
        serviceId: _serviceId,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusText = 'Ralat imbasan: $e';
        });
        _radarController.stop();
      }
    }
  }

  Future<void> _stopScanning() async {
    await Nearby().stopDiscovery();
    if (mounted) {
      setState(() {
        _isScanning = false;
        _statusText = _isConnected
            ? 'Disambungkan ke ${_connectedEndpoints.length} peranti'
            : 'Imbasan dihentikan.';
      });
      _radarController.stop();
    }
  }

  Future<void> _disconnectAll() async {
    await Nearby().stopAllEndpoints();
    if (mounted) {
      setState(() {
        _connectedEndpoints.clear();
        _discoveredEndpoints.clear();
        _isScanning = false;
        _statusText = 'Semua sambungan diputuskan.';
      });
      _radarController.stop();
    }
  }

  /// Sends a real SOS incident report through the Ad Hoc mesh — the same
  /// report the Home screen's SOS button creates, just routed hop-by-hop
  /// over Nearby Connections instead of a direct connection. If this device
  /// itself has internet it uploads immediately; otherwise it queues locally
  /// (as a fallback) and relays the encoded report to every connected peer.
  Future<void> _sendSOS() async {
    if (_connectedEndpoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Tiada peranti disambungkan',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    final userProvider = context.read<UserProvider>();
    if (userProvider.currentUser == null) {
      await userProvider.loadUser();
    }

    final note = _messageController.text.trim();
    final description = note.isNotEmpty
        ? 'SOS Kecemasan (via Ad Hoc): $note'
        : 'SOS Kecemasan — dihantar melalui rangkaian Ad Hoc (tiada internet).';

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 3)),
      );
    } catch (e) {
      debugPrint('Adhoc SOS location error: $e');
    }
    final lat = position?.latitude ?? 2.9277;
    final lng = position?.longitude ?? 101.7809;

    final sosIncident = IncidentModel(
      id: '',
      category: 'SOS',
      priority: 'TINGGI',
      description: description,
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      status: 'pending',
      userId: userProvider.idPengguna,
      userEmail: userProvider.emel,
      locationName: position != null
          ? 'GPS: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
          : 'UKM Kampus (via Ad Hoc)',
      mapsUrl: IncidentModel.generateMapsUrl(lat, lng),
    );

    final log =
        _MessageLog(message: description, timestamp: DateTime.now(), isIncoming: false);
    setState(() {
      _messageLogs.add(log);
      _messageController.clear();
    });

    final online = await SosQueueService.hasInternet();
    int sent = 0;

    if (online) {
      try {
        await FirebaseFirestore.instance
            .collection(IncidentModel.collection)
            .add(sosIncident.toFirestore());
        if (mounted) {
          setState(() {
            log.status = 'delivered';
            _statusText = 'SOS dihantar terus ke Firebase (internet tersedia)';
          });
        }
      } catch (e) {
        debugPrint('Adhoc SOS direct upload error: $e');
        await SosQueueService().queueSOS(sosIncident);
      }
    } else {
      await SosQueueService().queueSOS(sosIncident);

      // Build a unique message ID so each hop can deduplicate the relay
      final msgId =
          '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}';
      final encoded = SosQueueService.encodeForRelay(sosIncident);
      final rawPayload = '$msgId|$_sosRelayPrefix$encoded';
      _seenMessageIds.add(msgId); // don't re-process our own relayed echo

      final bytes = Uint8List.fromList(rawPayload.codeUnits);
      for (final endpointId in List<String>.from(_connectedEndpoints.keys)) {
        try {
          await Nearby().sendBytesPayload(endpointId, bytes);
          sent++;
        } catch (e) {
          debugPrint('SOS send error to $endpointId: $e');
        }
      }

      if (mounted) {
        setState(() {
          log.status = sent > 0 ? 'delivered' : 'sending';
          _statusText = sent > 0
              ? 'SOS direlai ke $sent peranti berdekatan'
              : 'SOS disimpan tempatan — tiada peranti disambungkan';
        });
      }
    }

    for (final peerName in _connectedEndpoints.values) {
      _logHop(action: 'message_sent', peerName: peerName, message: description);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: Colors.white.withValues(alpha: 0.9),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Rangkaian Ad Hoc',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.onSurface)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off, size: 64, color: AppColors.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Tidak Disokong pada Web',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                'Ciri Rangkaian Ad Hoc menggunakan Wi-Fi Direct dan Bluetooth yang hanya tersedia pada peranti Android.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Rangkaian Ad Hoc',
            style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.onSurface)),
        actions: [
          if (_isConnected)
            TextButton.icon(
              onPressed: _disconnectAll,
              icon: const Icon(Icons.link_off, size: 16, color: Colors.red),
              label: Text('Putus',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red)),
            ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (_isConnected
                      ? Colors.green
                      : _isReady
                          ? Colors.orange
                          : Colors.grey)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _isConnected
                    ? Icons.wifi_tethering
                    : _isReady
                        ? Icons.wifi
                        : Icons.wifi_off,
                color: _isConnected
                    ? Colors.green
                    : _isReady
                        ? Colors.orange
                        : Colors.grey,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                _isConnected ? 'AKTIF' : _isReady ? 'SEDIA' : 'OFFLINE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _isConnected
                      ? Colors.green
                      : _isReady
                          ? Colors.orange
                          : Colors.grey,
                ),
              ),
            ]),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.inverseSurface, Color(0xFF2D2D3F)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.info_outline, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 8),
                Text('MOD KOMUNIKASI KECEMASAN',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.greenAccent,
                        letterSpacing: 2)),
              ]),
              const SizedBox(height: 8),
              Text(
                'Hantar isyarat SOS tanpa internet menggunakan Wi-Fi Direct dan Bluetooth Mesh (Google Nearby Connections). Laporan direlai berperingkat melalui semua peranti yang berhubung sehingga sampai ke peranti yang mempunyai internet, lalu dimuat naik terus ke Firebase.',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.5),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Network topology visualizer
          Text('TOPOLOGI RANGKAIAN MASA NYATA',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 2)),
          const SizedBox(height: 12),
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: -5)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AnimatedBuilder(
                animation: _radarController,
                builder: (_, __) => CustomPaint(
                  painter: _TopologyPainter(
                    isScanning: _isScanning,
                    isConnected: _isConnected,
                    peers: _discoveredEndpoints.length,
                    connectedPeers: _connectedEndpoints.length,
                    radarValue: _radarController.value,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Status strip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(
                  color: _isConnected
                      ? Colors.green
                      : _isScanning
                          ? Colors.orange
                          : _isReady
                              ? AppColors.secondary
                              : Colors.grey,
                  width: 4,
                ),
              ),
            ),
            child: Row(children: [
              if (_isScanning)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.orange))
              else
                Icon(
                  _isConnected
                      ? Icons.check_circle
                      : _isReady
                          ? Icons.radio_button_unchecked
                          : Icons.error_outline,
                  color: _isConnected
                      ? Colors.green
                      : _isReady
                          ? AppColors.secondary
                          : Colors.grey,
                  size: 18,
                ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(_statusText,
                      style:
                          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 24),

          // Permission denied state
          if (_permissionDenied) ...[
            Center(
              child: Column(children: [
                const Icon(Icons.lock_outline,
                    color: AppColors.onSurfaceVariant, size: 48),
                const SizedBox(height: 12),
                Text('Kebenaran Diperlukan',
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  'Benarkan akses Lokasi dan Bluetooth (Scan, Connect, Advertise) untuk menggunakan rangkaian Ad Hoc.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ElevatedButton(
                    onPressed: () => openAppSettings(),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text('Buka Tetapan',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async {
                      setState(() {
                        _permissionDenied = false;
                        _statusText = 'Meminta kebenaran semula...';
                      });
                      await _initNearby();
                    },
                    style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text('Cuba Semula',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ]),
              ]),
            ),
          ] else ...[
            // Scan / Stop scan button
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (!_isReady)
                      ? null
                      : _isScanning
                          ? _stopScanning
                          : _startScanning,
                  icon: Icon(_isScanning ? Icons.stop : Icons.search,
                      color: Colors.white),
                  label: Text(
                    _isScanning ? 'HENTI IMBASAN' : 'IMBAS PERANTI BERDEKATAN',
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isScanning ? Colors.red.shade700 : AppColors.secondary,
                    disabledBackgroundColor:
                        AppColors.secondary.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // Discovered peers
            if (_discoveredEndpoints.isNotEmpty) ...[
              Text('PERANTI DITEMUI (${_discoveredEndpoints.length})',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                      letterSpacing: 2)),
              const SizedBox(height: 12),
              ..._discoveredEndpoints.entries
                  .map((e) => _buildPeerTile(e.key, e.value)),
              const SizedBox(height: 24),
            ],

            // SOS compose (only when connected)
            if (_isConnected) ...[
              Text(
                  'HANTAR ISYARAT SOS (${_connectedEndpoints.length} peranti)',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                      letterSpacing: 2)),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Huraikan kecemasan (pilihan)...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendSOS,
                  icon: const Icon(Icons.sos_rounded, color: Colors.white, size: 18),
                  label: Text('HANTAR SOS VIA AD HOC',
                      style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // SOS logs
            if (_messageLogs.isNotEmpty) ...[
              Text('LOG SOS',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                      letterSpacing: 2)),
              const SizedBox(height: 12),
              ..._messageLogs.reversed.map((log) => _buildLogTile(log)),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _buildPeerTile(String endpointId, String name) {
    final isConnected = _connectedEndpoints.containsKey(endpointId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isConnected ? Colors.green : AppColors.secondary)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.phone_android,
              color: isConnected ? Colors.green : AppColors.secondary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(endpointId,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
        ])),
        if (isConnected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text('DISAMBUNG',
                style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w800, color: Colors.green)),
          ),
      ]),
    );
  }

  Widget _buildLogTile(_MessageLog log) {
    final done = log.status == 'delivered' || log.status == 'received';
    final isIncoming = log.isIncoming;
    final accent =
        isIncoming ? AppColors.secondary : (done ? Colors.green : Colors.orange);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100)),
            child: Text(
              isIncoming
                  ? 'SOS DITERIMA'
                  : done
                      ? 'SOS BERJAYA DIHANTAR'
                      : 'MENGHANTAR SOS...',
              style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w800, color: accent),
            ),
          ),
          Text(
            '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400),
          ),
        ]),
        const SizedBox(height: 8),
        Text(log.message,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface)),
      ]),
    );
  }
}

class _TopologyPainter extends CustomPainter {
  final bool isScanning, isConnected;
  final int peers, connectedPeers;
  final double radarValue;

  const _TopologyPainter({
    required this.isScanning,
    required this.isConnected,
    required this.peers,
    required this.connectedPeers,
    required this.radarValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Background rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.blue.withValues(alpha: 0.2);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, (size.height / 2.5) * (i / 3), ringPaint);
    }

    // Radar sweep
    if (isScanning) {
      final radarPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.blueAccent.withValues(alpha: 1.0 - radarValue);
      canvas.drawCircle(center, (size.height / 2.2) * radarValue, radarPaint);
    }

    // Self node
    final selfPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isConnected ? Colors.greenAccent : Colors.blueAccent;
    canvas.drawCircle(center, 8, selfPaint);

    // Peer nodes
    final displayCount = max(peers, connectedPeers);
    if (displayCount > 0) {
      for (int i = 0; i < displayCount; i++) {
        final angle = (2 * pi / displayCount) * i;
        final dist = size.height / 3.5;
        final nodePos =
            Offset(center.dx + cos(angle) * dist, center.dy + sin(angle) * dist);
        final isCon = i < connectedPeers;

        // Connection line
        final linePaint = Paint()
          ..color =
              isCon ? Colors.greenAccent : Colors.blueAccent.withValues(alpha: 0.3)
          ..strokeWidth = 1.5;
        canvas.drawLine(center, nodePos, linePaint);

        // Node dot
        final nodePaint = Paint()
          ..style = PaintingStyle.fill
          ..color =
              isCon ? Colors.greenAccent : Colors.blueAccent.withValues(alpha: 0.6);
        canvas.drawCircle(nodePos, 5, nodePaint);
      }
    }

    // Pulse for active connection
    if (isConnected) {
      final pulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.greenAccent.withValues(alpha: 0.4 + radarValue * 0.3);
      canvas.drawCircle(center, (size.height / 4), pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TopologyPainter old) =>
      old.isScanning != isScanning ||
      old.isConnected != isConnected ||
      old.peers != peers ||
      old.connectedPeers != connectedPeers ||
      old.radarValue != radarValue;
}
