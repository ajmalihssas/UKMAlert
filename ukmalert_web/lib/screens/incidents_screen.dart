import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import '../theme/app_theme.dart';
import '../models/incident_model.dart';

class IncidentsScreen extends StatefulWidget {
  final String peranan;
  const IncidentsScreen({super.key, required this.peranan});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();

  /// Accessible from dashboard and other screens for inline status update.
  static void showStatusDialog(
    BuildContext context,
    String docId,
    String currentStatus,
    String peranan,
  ) {
    showDialog(
      context: context,
      builder: (_) =>
          _StatusDialog(docId: docId, currentStatus: currentStatus),
    );
  }
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  String _statusFilter = 'semua';

  static const List<(String, String)> _statusOptions = [
    ('semua', 'Semua'),
    ('pending', 'Menunggu'),
    ('received', 'Diterima'),
    ('responding', 'Dalam Tindakan'),
    ('resolved', 'Selesai'),
  ];

  Stream<QuerySnapshot> _stream() {
    final base = FirebaseFirestore.instance
        .collection(IncidentModel.collection)
        .orderBy('tarikhMasa', descending: true);
    if (_statusFilter == 'semua') return base.snapshots();
    return base
        .where('statusLaporan', isEqualTo: _statusFilter)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Pengurusan Insiden',
              style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kText1)),
          const SizedBox(height: 4),
          Text('Kemaskini status laporan & SOS daripada pengguna',
              style: GoogleFonts.inter(fontSize: 13, color: kText2)),
          const SizedBox(height: 24),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusOptions.map((opt) {
                final isActive = _statusFilter == opt.$1;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _statusFilter = opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: isActive ? kPrimary : kSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isActive ? kPrimary : kBorder),
                    ),
                    child: Text(
                      opt.$2,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : kText2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Incident list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _stream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: kPrimary));
                }
                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            color: kText3.withValues(alpha: 0.5),
                            size: 64),
                        const SizedBox(height: 12),
                        Text('Tiada laporan dijumpai.',
                            style: GoogleFonts.inter(
                                fontSize: 15, color: kText3)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, i) {
                    final doc = snapshot.data!.docs[i];
                    final incident =
                        IncidentModel.fromFirestore(doc);
                    return _IncidentCard(
                      incident: incident,
                      docId: doc.id,
                      peranan: widget.peranan,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Incident card ─────────────────────────────────────────────────────────────
class _IncidentCard extends StatelessWidget {
  final IncidentModel incident;
  final String docId;
  final String peranan;
  const _IncidentCard(
      {required this.incident, required this.docId, required this.peranan});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(incident.status);
    final catColor    = _catColor(incident.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: category badge + status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  incident.category.isNotEmpty
                      ? incident.category
                      : 'TIDAK DIKETAHUI',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: catColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  IncidentModel.statusLabel(incident.status),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: description
          Text(
            incident.description.isNotEmpty
                ? incident.description
                : '(Tiada penerangan)',
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600, color: kText1),
          ),
          const SizedBox(height: 6),

          // Row 3: meta info
          Row(
            children: [
              _metaChip(Icons.person_outline,
                  incident.userId.isNotEmpty ? incident.userId : '-'),
              const SizedBox(width: 12),
              _metaChip(
                  Icons.location_on_outlined,
                  incident.locationName.isNotEmpty
                      ? incident.locationName
                      : '${incident.latitude.toStringAsFixed(4)}, '
                          '${incident.longitude.toStringAsFixed(4)}'),
              const SizedBox(width: 12),
              _metaChip(
                  Icons.schedule_outlined,
                  DateFormat('dd/MM/yyyy HH:mm')
                      .format(incident.timestamp)),
            ],
          ),
          const SizedBox(height: 12),

          // Row 4: action buttons
          Row(
            children: [
              OutlinedButton(
                onPressed: () => _showDetail(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kText2,
                  side: const BorderSide(color: kBorder),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Butiran',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              // Google Maps link button
              if (incident.mapsUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => html.window.open(incident.mapsUrl, '_blank'),
                  icon: const Icon(Icons.location_on, size: 14),
                  label: Text('Maps',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kDanger,
                    side: const BorderSide(color: kDanger),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _StatusDialog(
                      docId: docId,
                      currentStatus: incident.status),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: kSurface,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 0,
                ),
                child: Text('Kemaskini Status',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: kText3),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12, color: kText3),
            ),
          ),
        ],
      );

  void _showDetail(BuildContext context) {
    final i = incident;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Butiran Laporan',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kText1)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Jenis', i.category),
              _detailRow('Keterangan', i.description),
              _detailRow('Pelapor (Matrik)', i.userId),
              _detailRow('E-mel', i.userEmail),
              _detailRow(
                  'Lokasi',
                  i.locationName.isNotEmpty
                      ? i.locationName
                      : '${i.latitude.toStringAsFixed(5)}, '
                          '${i.longitude.toStringAsFixed(5)}'),
              _detailRow('Koordinat',
                  '${i.latitude.toStringAsFixed(6)}, ${i.longitude.toStringAsFixed(6)}'),
              if (i.mapsUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text('Google Maps',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600, color: kText3)),
                      ),
                      InkWell(
                        onTap: () => html.window.open(i.mapsUrl, '_blank'),
                        child: Text(
                          i.mapsUrl,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: kPrimary,
                              decoration: TextDecoration.underline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              _detailRow('Tarikh',
                  DateFormat('dd/MM/yyyy HH:mm').format(i.timestamp)),
              _detailRow('Status', IncidentModel.statusLabel(i.status)),
              if (i.notes.isNotEmpty) _detailRow('Catatan', i.notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: kPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kText3)),
            ),
            Expanded(
              child: Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: kText1)),
            ),
          ],
        ),
      );

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'resolved':
        return kSuccess;
      case 'responding':
        return kWarning;
      case 'received':
        return kInfo;
      default:
        return kDanger;
    }
  }

  Color _catColor(String c) {
    switch (c.toUpperCase()) {
      case 'SOS':
        return kDanger;
      case 'MEDICAL':
        return kInfo;
      case 'FIRE':
        return kWarning;
      default:
        return kPrimary;
    }
  }
}

// ── Status update dialog ───────────────────────────────────────────────────────
class _StatusDialog extends StatefulWidget {
  final String docId;
  final String currentStatus;
  const _StatusDialog(
      {required this.docId, required this.currentStatus});

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  late String _selected;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  static const List<(String, String, Color)> _options = [
    ('pending', 'Menunggu', kDanger),
    ('received', 'Diterima', kInfo),
    ('responding', 'Bantuan Dalam Perjalanan', kWarning),
    ('resolved', 'Selesai', kSuccess),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentStatus;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final data = <String, dynamic>{'statusLaporan': _selected};
    if (_notesCtrl.text.trim().isNotEmpty) {
      data['notes'] = _notesCtrl.text.trim();
    }
    await FirebaseFirestore.instance
        .collection(IncidentModel.collection)
        .doc(widget.docId)
        .update(data);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Status dikemaskini: ${IncidentModel.statusLabel(_selected)}'),
        backgroundColor: kSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Kemaskini Status',
          style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kText1)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('STATUS BARU',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kText3,
                    letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _options.map((opt) {
                final isSelected = _selected == opt.$1;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selected = opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? opt.$3
                          : opt.$3.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: opt.$3,
                          width: isSelected ? 0 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.check,
                                color: Colors.white, size: 13),
                          ),
                        Text(
                          opt.$2,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : opt.$3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('CATATAN PEGAWAI (PILIHAN)',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kText3,
                    letterSpacing: 1.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 13, color: kText1),
              decoration: InputDecoration(
                hintText:
                    'cth: Pasukan telah dihantar ke lokasi kejadian...',
                hintStyle:
                    GoogleFonts.inter(color: kText3, fontSize: 13),
                filled: true,
                fillColor: kBg,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: kPrimary, width: 1.5)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text('Batal',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, color: kText2)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: kSurface,
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text('Simpan',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ],
    );
  }
}
