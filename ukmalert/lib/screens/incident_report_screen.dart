import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/incident_model.dart';
import '../providers/user_provider.dart';
class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  int _selectedCategory = 0;
  int _selectedPriority = 0;
  final _descriptionController = TextEditingController();
  String _currentLocationName = 'Mengesan lokasi...';
  Position? _selectedPosition;
  final MapController _miniMapController = MapController();
  bool _miniMapReady = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _determineInitialPosition();
  }

  Future<void> _determineInitialPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (serviceEnabled &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (!mounted) return;
        setState(() => _selectedPosition = position);
        if (_miniMapReady) {
          _miniMapController.move(LatLng(position.latitude, position.longitude), 17.0);
        }
        final name = await _reverseGeocode(position.latitude, position.longitude);
        if (name != null && mounted) setState(() => _currentLocationName = name);
      } else {
        if (mounted) setState(() => _currentLocationName = 'Kolej Keris Mas');
      }
    } catch (e) {
      if (mounted) setState(() => _currentLocationName = 'Kolej Keris Mas');
    }
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { setState(() => _isLocating = false); return; }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _isLocating = false); return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() { _selectedPosition = position; _isLocating = false; });
      if (_miniMapReady) {
        _miniMapController.move(LatLng(position.latitude, position.longitude), 17.0);
      }
      final name = await _reverseGeocode(position.latitude, position.longitude);
      if (name != null && mounted) setState(() => _currentLocationName = name);
    } catch (e) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'UKMAlert/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final display = (data['display_name'] as String? ?? '').trim();
        if (display.isNotEmpty) return display.split(',').first.trim();
      }
    } catch (_) {}
    return null;
  }

  static const Map<String, List<String>> _locationsByCategory = {
    'Kolej Kediaman': [
      'Kolej Keris Mas',
      'Kolej Pendeta Za\'ba',
      'Kolej Burhanuddin Helmi',
      'Kolej Ibrahim Yaa\'kub',
      'Kolej Rahim Kajai',
      'Kolej Ibu Zain',
      'Kolej Dato\' Onn',
      'Kolej Tun Hussein Onn',
      'Kolej Ungku Omar',
      'Kolej Aminuddin Baki',
      'Kolej Ke-13',
      'Kolej Tun Syed Nasir',
      'Kolej Tun Dr Ismail',
    ],
    'Fakulti': [
      'Fakulti Sains & Teknologi Maklumat (FTSM)',
      'Fakulti Kejuruteraan & Alam Bina (FKAB)',
      'Fakulti Sains & Teknologi (FST)',
      'Fakulti Ekonomi & Pengurusan (FEP)',
      'Fakulti Undang-undang (FUU)',
      'Fakulti Perubatan (FPer)',
      'Fakulti Pergigian (FPg)',
      'Fakulti Farmasi (FF)',
      'Fakulti Sains Kesihatan Bersekutu (FSKB)',
      'Fakulti Sains Sosial & Kemanusiaan (FSSK)',
      'Fakulti Pendidikan (FP)',
      'Fakulti Pengajian Islam (FPI)',
    ],
    'Kemudahan & Lain-lain': [
      'Dewan Canselor Tun Abdul Razak (DECTAR)',
      'Perpustakaan Tun Seri Lanang',
      'Pusat Kesihatan UKM',
      'UKM Medical Centre (UKMMC)',
      'Masjid UKM',
      'Stadium UKM',
      'Kompleks Sukan UKM',
      'Pusat Pelajar UKM',
      'Kompleks Mahasiswa UKM',
      'Pusat Islam UKM',
      'Pusat Penataran Ilmu & Bahasa',
      'Kompleks Orkid',
      'Terminal Bas UKM',
      'Pintu Masuk Utama UKM',
      'Dataran UKM',
      'Jalan Utama UKM',
    ],
  };

  Future<void> _selectLocation() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF152038),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3F62),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    'Pilih Lokasi',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF2A3F62)),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: _locationsByCategory.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFC9A227),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          ...entry.value.map((loc) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF4A8FFF)),
                            title: Text(
                              loc,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            onTap: () {
                              setState(() => _currentLocationName = loc);
                              Navigator.pop(context);
                            },
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.minor_crash, 'label': 'ACCIDENT'},
    {'icon': Icons.local_fire_department, 'label': 'FIRE'},
    {'icon': Icons.medical_services, 'label': 'MEDICAL'},
    {'icon': Icons.handyman, 'label': 'MAINTENANCE'},
    {'icon': Icons.security, 'label': 'THEFT'},
  ];

  final List<String> _priorities = ['RENDAH', 'SEDERHANA', 'TINGGI'];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // Dark theme colours used throughout this screen
  static const Color _bg        = Color(0xFF0A1628);
  static const Color _card      = Color(0xFF152038);
  static const Color _cardAlt   = Color(0xFF1C2D4A);
  static const Color _border    = Color(0xFF2A3F62);
  static const Color _textPrim  = Color(0xFFFFFFFF);
  static const Color _textSec   = Color(0xFFADBACC);
  static const Color _accent    = Color(0xFF4A8FFF);
  static const Color _gold      = Color(0xFFC9A227);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrim),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'UKMALERT',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _accent,
            letterSpacing: 1,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: _cardAlt,
              child: const Icon(Icons.person, color: _gold, size: 20),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'LAPORAN BARU',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.tertiary,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Butiran Insiden',
              style: GoogleFonts.manrope(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _textPrim,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 28),

            // ── Category Selection ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih Kategori',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: _textPrim,
                  ),
                ),
                Text(
                  'Wajib',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 112,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedCategory == index;
                  final cat = _categories[index];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 96,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? _accent.withValues(alpha: 0.18) : _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? _accent : _border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            color: isSelected ? _accent : _textSec,
                            size: 28,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            cat['label'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: isSelected ? _accent : _textSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // ── Location Section ─────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: _card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 160,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _miniMapController,
                            options: MapOptions(
                              initialCenter: _selectedPosition != null
                                  ? LatLng(_selectedPosition!.latitude, _selectedPosition!.longitude)
                                  : const LatLng(2.9277, 101.7809),
                              initialZoom: 17,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                              onMapReady: () {
                                setState(() => _miniMapReady = true);
                                if (_selectedPosition != null) {
                                  _miniMapController.move(
                                    LatLng(_selectedPosition!.latitude, _selectedPosition!.longitude),
                                    17.0,
                                  );
                                }
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.ukmalert',
                              ),
                              if (_selectedPosition != null)
                                MarkerLayer(markers: [
                                  Marker(
                                    point: LatLng(_selectedPosition!.latitude, _selectedPosition!.longitude),
                                    width: 40,
                                    height: 48,
                                    alignment: Alignment.topCenter,
                                    child: const Icon(Icons.location_pin, color: AppColors.tertiary, size: 40),
                                  ),
                                ]),
                            ],
                          ),
                          if (_isLocating)
                            Container(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: _gold, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _currentLocationName,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: _textPrim,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLocating ? null : _detectCurrentLocation,
                                  icon: _isLocating
                                      ? const SizedBox(
                                          width: 14, height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
                                        )
                                      : const Icon(Icons.my_location, size: 14),
                                  label: Text(
                                    'LOKASI SEMASA',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _gold,
                                    side: const BorderSide(color: _gold),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _selectLocation,
                                  icon: const Icon(Icons.list, size: 14),
                                  label: Text(
                                    'PILIH LOKASI',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _accent,
                                    side: const BorderSide(color: _accent),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Description ──────────────────────────────────────────────────
            Text(
              'Keterangan Insiden',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: _textPrim,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              style: GoogleFonts.inter(fontSize: 14, color: _textPrim),
              cursorColor: _accent,
              decoration: InputDecoration(
                hintText: 'Sila jelaskan keadaan insiden secara ringkas...',
                hintStyle: GoogleFonts.inter(
                  color: _textSec,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: _card,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _accent, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),

            // ── Media buttons ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo, color: _textSec, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'AMBIL GAMBAR',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _textSec,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.attach_file, color: _textSec, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'LAMPIRKAN',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _textSec,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Priority Level ───────────────────────────────────────────────
            Text(
              'Tahap Keutamaan',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: _textPrim,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: List.generate(3, (index) {
                  final isSelected = _selectedPriority == index;
                  final colors = [
                    const Color(0xFF2E7D32), // low — green
                    const Color(0xFFE65100), // medium — orange
                    const Color(0xFFB71C1C), // high — red
                  ];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPriority = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: isSelected ? colors[index] : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          _priorities[index],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : _textSec,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 36),

            // ── Submit button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (_descriptionController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sila masukkan keterangan insiden.', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        backgroundColor: Colors.orange.shade800,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                    return;
                  }

                  final userProvider = context.read<UserProvider>();
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  );

                  try {
                    if (userProvider.currentUser == null) {
                      await userProvider.loadUser();
                    }

                    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                    LocationPermission permission = await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                    }

                    Position? position;
                    if (serviceEnabled && permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
                      position = await Geolocator.getCurrentPosition(
                        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                      );
                    }

                    position ??= _selectedPosition;

                    final lat = position?.latitude ?? 2.9277;
                    final lng = position?.longitude ?? 101.7809;

                    final newIncident = IncidentModel(
                      id: '',
                      category: _categories[_selectedCategory]['label'] as String,
                      priority: _priorities[_selectedPriority],
                      description: _descriptionController.text.trim(),
                      latitude: lat,
                      longitude: lng,
                      timestamp: DateTime.now(),
                      status: 'pending',
                      userId: userProvider.idPengguna,
                      userEmail: userProvider.emel,
                      locationName: _currentLocationName,
                      mapsUrl: IncidentModel.generateMapsUrl(lat, lng),
                    );

                    await FirebaseFirestore.instance
                        .collection(IncidentModel.collection)
                        .add(newIncident.toFirestore());

                    if (!mounted) return;
                    navigator.pop();

                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => const _IncidentSuccessScreen(),
                        fullscreenDialog: true,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    navigator.pop();

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Gagal menghantar laporan. Sila cuba lagi.', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                     );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Hantar Laporan',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'LAPORAN ANDA AKAN DIHANTAR KE PUSAT KAWALAN UKM SERTA-MERTA',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _textSec.withValues(alpha: 0.7),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentSuccessScreen extends StatelessWidget {
  const _IncidentSuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D2E1A),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2E7D32), width: 2),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF4CAF50),
                    size: 68,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Terima Kasih!',
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Laporan anda telah berjaya dihantar.\n\nPihak bertanggungjawab akan bertindak segera.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFFADBACC),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 52),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (_) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A8FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Kembali ke Menu',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


