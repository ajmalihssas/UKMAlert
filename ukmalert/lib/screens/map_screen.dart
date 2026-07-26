import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../models/incident_model.dart';
import '../models/notification_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final LatLng _ukm = const LatLng(2.9277, 101.7809);

  bool _mapReady = false;
  LatLng? _userPosition;
  LatLng? _searchMarker;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  // Live Firestore data
  List<IncidentModel> _activeIncidents = [];
  List<NotificationModel> _adminNotifications = [];
  StreamSubscription<QuerySnapshot>? _incidentSub;
  StreamSubscription<QuerySnapshot>? _notifSub;

  // Filter
  String _activeFilter = 'SEMUA';
  static const _filters = ['SEMUA', 'SOS', 'ACCIDENT', 'FIRE', 'MEDICAL', 'THEFT'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _determinePosition());
    _subscribeIncidents();
    _subscribeNotifications();
  }

  void _subscribeIncidents() {
    _incidentSub = FirebaseFirestore.instance
        .collection(IncidentModel.collection)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _activeIncidents = snap.docs
            .map((d) => IncidentModel.fromFirestore(d))
            .where((i) => i.status != 'resolved')
            .toList();
      });
    });
  }

  void _subscribeNotifications() {
    _notifSub = FirebaseFirestore.instance
        .collection(NotificationModel.collection)
        .where('noMatriks', isEqualTo: '')
        .orderBy('tarikhHantar', descending: true)
        .limit(10)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _adminNotifications =
            snap.docs.map((d) => NotificationModel.fromFirestore(d)).toList();
      });
    });
  }

  @override
  void dispose() {
    _incidentSub?.cancel();
    _notifSub?.cancel();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) return;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
    }
    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _userPosition = ll);
      if (_mapReady) _mapController.move(ll, 16.0);
    }
  }

  void _onSearchChanged(String q) {
    _debounceTimer?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () => _searchLocation(q.trim()));
  }

  Future<void> _searchLocation(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=6&countrycodes=my',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'UKMAlert/1.0'});
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _searchResults = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectResult(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat'] ?? '') ?? 0.0;
    final lon = double.tryParse(result['lon'] ?? '') ?? 0.0;
    final pos = LatLng(lat, lon);
    final full = (result['display_name'] ?? '').toString();
    final short = full.split(',').first.trim();
    setState(() {
      _searchMarker = pos;
      _searchResults = [];
      _searchController.text = short;
    });
    FocusScope.of(context).unfocus();
    if (_mapReady) _mapController.move(pos, 16.0);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() { _searchResults = []; _searchMarker = null; });
  }

  // ── Incident helpers ────────────────────────────────────────────────────────

  List<IncidentModel> get _filtered {
    if (_activeFilter == 'SEMUA') return _activeIncidents;
    return _activeIncidents.where((i) => i.category.toUpperCase() == _activeFilter).toList();
  }

  Color _catColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'SOS':         return AppColors.primary;
      case 'FIRE':        return Colors.deepOrange;
      case 'ACCIDENT':    return Colors.orange.shade700;
      case 'MEDICAL':     return const Color(0xFF2563EB);
      case 'THEFT':       return Colors.purple.shade600;
      case 'MAINTENANCE': return Colors.grey.shade600;
      default:            return AppColors.primary;
    }
  }

  IconData _catIcon(String cat) {
    switch (cat.toUpperCase()) {
      case 'SOS':         return Icons.emergency;
      case 'FIRE':        return Icons.local_fire_department;
      case 'ACCIDENT':    return Icons.minor_crash;
      case 'MEDICAL':     return Icons.medical_services;
      case 'THEFT':       return Icons.security;
      case 'MAINTENANCE': return Icons.handyman;
      default:            return Icons.warning_amber;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':    return 'Menunggu';
      case 'received':   return 'Diterima';
      case 'responding': return 'Dalam Tindakan';
      default:           return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':    return AppColors.primary;
      case 'received':   return const Color(0xFF2563EB);
      case 'responding': return const Color(0xFFD97706);
      default:           return Colors.grey;
    }
  }

  void _showIncidentSheet(IncidentModel inc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (_) => _IncidentSheet(inc: inc, catColor: _catColor, catIcon: _catIcon,
          statusLabel: _statusLabel, statusColor: _statusColor),
    );
  }

  void _showNotifPanel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (_) => _NotifPanel(notifications: _adminNotifications),
    );
  }

  List<Marker> get _incidentMarkers => _filtered.map((inc) {
    final color = _catColor(inc.category);
    final icon  = _catIcon(inc.category);
    return Marker(
      point: LatLng(inc.latitude, inc.longitude),
      width: 48,
      height: 56,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _showIncidentSheet(inc),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            CustomPaint(painter: _TrianglePainter(color: color), size: const Size(12, 7)),
          ],
        ),
      ),
    );
  }).toList();

  void _zoomIn()  { if (!_mapReady) return; final c = _mapController.camera; _mapController.move(c.center, (c.zoom + 1).clamp(2.0, 19.0)); }
  void _zoomOut() { if (!_mapReady) return; final c = _mapController.camera; _mapController.move(c.center, (c.zoom - 1).clamp(2.0, 19.0)); }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _ukm,
                initialZoom: 15,
                onMapReady: () => setState(() {
                  _mapReady = true;
                  if (_userPosition != null) _mapController.move(_userPosition!, 16.0);
                }),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.ukmalert',
                ),
                MarkerLayer(markers: [
                  // User position
                  if (_userPosition != null)
                    Marker(
                      point: _userPosition!,
                      width: 44, height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 22),
                      ),
                    ),
                  // Search marker
                  if (_searchMarker != null)
                    Marker(
                      point: _searchMarker!,
                      width: 48, height: 56,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_pin, color: Color(0xFF9E0000), size: 52),
                    ),
                  // Incident markers
                  ..._incidentMarkers,
                ]),
              ],
            ),
          ),

          // ── Search bar ─────────────────────────────────────────────────────
          Positioned(
            top: topPad + 12, left: 16, right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              shadowColor: Colors.black.withValues(alpha: 0.15),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) { if (v.trim().isNotEmpty) _searchLocation(v.trim()); },
                decoration: InputDecoration(
                  hintText: 'Cari lokasi di Malaysia...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: _isSearching
                      ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                      : const Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey, size: 20), onPressed: _clearSearch)
                      : null,
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),

          // ── Search results dropdown ─────────────────────────────────────────
          if (_searchResults.isNotEmpty)
            Positioned(
              top: topPad + 68, left: 16, right: 16,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                shadowColor: Colors.black.withValues(alpha: 0.15),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.white,
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      padding: EdgeInsets.zero, shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                      itemBuilder: (ctx, i) {
                        final r = _searchResults[i];
                        final full = (r['display_name'] ?? '').toString();
                        final title = full.split(',').first.trim();
                        final sub = full.contains(',') ? full.substring(full.indexOf(',') + 1).trim() : '';
                        return ListTile(
                          leading: const Icon(Icons.place_outlined, color: AppColors.primary),
                          title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: sub.isNotEmpty ? Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)) : null,
                          onTap: () => _selectResult(r),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

          // ── Incident count + legend (top-right) ────────────────────────────
          Positioned(
            top: topPad + 12,
            right: 16 + MediaQuery.of(context).size.width - 16 - 16 + 16,
            child: const SizedBox.shrink(),
          ),

          // ── Zoom buttons ───────────────────────────────────────────────────
          Positioned(
            bottom: 200, right: 16,
            child: Column(children: [
              _zoomBtn(Icons.add, _zoomIn),
              const SizedBox(height: 8),
              _zoomBtn(Icons.remove, _zoomOut),
            ]),
          ),

          // ── Notification bell ──────────────────────────────────────────────
          Positioned(
            bottom: 200, left: 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: _showNotifPanel,
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.notifications_outlined, color: AppColors.secondary, size: 24),
                  ),
                ),
                if (_adminNotifications.isNotEmpty)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      width: 18, height: 18,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          _adminNotifications.length > 9 ? '9+' : '${_adminNotifications.length}',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── My location FAB ────────────────────────────────────────────────
          Positioned(
            bottom: 144, right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _determinePosition,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.my_location, color: Colors.white, size: 20),
            ),
          ),

          // ── Filter chips (bottom) ──────────────────────────────────────────
          Positioned(
            bottom: 100, left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Active incident count bar
                if (_activeIncidents.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${_activeIncidents.length} INSIDEN AKTIF DI KAMPUS',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                // Category filter chips
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = _filters[i];
                      final active = _activeFilter == f;
                      final count = f == 'SEMUA'
                          ? _activeIncidents.length
                          : _activeIncidents.where((inc) => inc.category.toUpperCase() == f).length;
                      return GestureDetector(
                        onTap: () => setState(() => _activeFilter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? _filterColor(f) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                f == 'SEMUA' ? 'Semua' : _filterLabel(f),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: active ? Colors.white : AppColors.onSurfaceVariant,
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: active ? Colors.white.withValues(alpha: 0.3) : _filterColor(f).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: active ? Colors.white : _filterColor(f),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _filterColor(String f) {
    switch (f) {
      case 'SOS':         return AppColors.primary;
      case 'FIRE':        return Colors.deepOrange;
      case 'ACCIDENT':    return Colors.orange.shade700;
      case 'MEDICAL':     return const Color(0xFF2563EB);
      case 'THEFT':       return Colors.purple.shade600;
      case 'MAINTENANCE': return Colors.grey.shade600;
      default:            return AppColors.secondary;
    }
  }

  String _filterLabel(String f) {
    switch (f) {
      case 'SOS':         return 'SOS';
      case 'FIRE':        return 'Kebakaran';
      case 'ACCIDENT':    return 'Kemalangan';
      case 'MEDICAL':     return 'Perubatan';
      case 'THEFT':       return 'Kecurian';
      case 'MAINTENANCE': return 'Penyelenggaraan';
      default:            return f;
    }
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}

// ── Triangle pointer for marker ────────────────────────────────────────────────
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}

// ── Incident detail bottom sheet ───────────────────────────────────────────────
class _IncidentSheet extends StatelessWidget {
  final IncidentModel inc;
  final Color Function(String) catColor;
  final IconData Function(String) catIcon;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;

  const _IncidentSheet({
    required this.inc,
    required this.catColor,
    required this.catIcon,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = catColor(inc.category);
    final icon  = catIcon(inc.category);
    final diff  = DateTime.now().difference(inc.timestamp);
    final timeAgo = diff.inMinutes < 60
        ? '${diff.inMinutes} minit lepas'
        : diff.inHours < 24
            ? '${diff.inHours} jam lepas'
            : '${inc.timestamp.day}/${inc.timestamp.month}/${inc.timestamp.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                inc.category,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.onSurface),
              ),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor(inc.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel(inc.status),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor(inc.status))),
                ),
                const SizedBox(width: 8),
                Text(timeAgo, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ]),
            ])),
          ]),
          const SizedBox(height: 20),
          // Description
          if (inc.description.isNotEmpty) ...[
            Text('Keterangan', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Text(inc.description, style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface, height: 1.5)),
            const SizedBox(height: 16),
          ],
          // Location
          Row(children: [
            const Icon(Icons.location_on_outlined, color: AppColors.secondary, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(
              inc.locationName.isNotEmpty ? inc.locationName : 'Lokasi GPS (${inc.latitude.toStringAsFixed(4)}, ${inc.longitude.toStringAsFixed(4)})',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface),
            )),
          ]),
          // Priority
          if (inc.priority.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.flag_outlined, color: AppColors.tertiary, size: 16),
              const SizedBox(width: 6),
              Text('Keutamaan: ${inc.priority}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface)),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Notification panel bottom sheet ───────────────────────────────────────────
class _NotifPanel extends StatelessWidget {
  final List<NotificationModel> notifications;
  const _NotifPanel({required this.notifications});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                const Icon(Icons.campaign, color: AppColors.secondary),
                const SizedBox(width: 10),
                Text('Notifikasi Pihak Berkuasa',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                Text('${notifications.length} rekod',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: notifications.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.notifications_none, size: 48, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text('Tiada notifikasi aktif', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
                    ]),
                  )
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = notifications[i];
                      final typeColor = n.type == 'emergency' ? AppColors.primary
                          : n.type == 'update' ? const Color(0xFFD97706)
                          : AppColors.secondary;
                      final typeIcon  = n.type == 'emergency' ? Icons.emergency_outlined
                          : n.type == 'update' ? Icons.update_outlined
                          : Icons.campaign_outlined;
                      final diff = DateTime.now().difference(n.timestamp);
                      final ago = diff.inMinutes < 60 ? '${diff.inMinutes}m' : '${diff.inHours}j';
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                            child: Icon(typeIcon, color: typeColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n.title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(n.message, style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ])),
                          const SizedBox(width: 8),
                          Text(ago, style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant)),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
