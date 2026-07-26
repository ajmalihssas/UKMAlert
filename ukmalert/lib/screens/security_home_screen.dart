import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/incident_model.dart';

/// KF5: Mengurus Insiden (Pegawai Keselamatan)
class SecurityHomeScreen extends StatelessWidget {
  const SecurityHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(child: _buildStatsOverview()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            sliver: SliverToBoxAdapter(child: Text('Laporan Terkini', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurface))),
          ),
          _buildIncidentList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/security_management'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
        label: Text('URUS SISTEM', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120, floating: true, pinned: true, elevation: 0,
      backgroundColor: AppColors.primary, automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Text('Pegawai Keselamatan', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
        background: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primaryContainer]))),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () => _confirmLogout(context),
        ),
      ],
    );
  }

  /// KF9: Pengesahan log keluar
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Log Keluar', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        content: Text('Adakah anda pasti ingin log keluar daripada aplikasi ini?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Tidak', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (ctx.mounted) { Navigator.pop(ctx); Navigator.pushReplacementNamed(context, '/login'); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Ya, Log Keluar', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// KF5: Statistik masa nyata daripada Firebase
  Widget _buildStatsOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(IncidentModel.collection).snapshots(),
      builder: (context, snapshot) {
        int active = 0, responding = 0, resolved = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['statusLaporan'] ?? data['status'] ?? 'pending').toString().toLowerCase();
            if (status == 'pending' || status == 'received') {
              active++;
            } else if (status == 'responding') {
              responding++;
            } else if (status == 'resolved') {
              resolved++;
            }
          }
        }
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            _buildStatCard('AKTIF', '$active', Colors.red),
            const SizedBox(width: 12),
            _buildStatCard('TINDAKAN', '$responding', Colors.orange),
            const SizedBox(width: 12),
            _buildStatCard('SELESAI', '$resolved', Colors.green),
          ]),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withValues(alpha:0.1), blurRadius: 20, offset: const Offset(0, 4))]),
        child: Column(children: [
          Text(value, style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _buildIncidentList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(IncidentModel.collection).orderBy('tarikhMasa', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
        if (snapshot.data!.docs.isEmpty) return SliverFillRemaining(child: Center(child: Text('Tiada insiden buat masa ini.', style: GoogleFonts.inter(color: Colors.grey.shade500))));
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(delegate: SliverChildBuilderDelegate(
            (context, index) {
              final doc = snapshot.data!.docs[index];
              final incident = IncidentModel.fromFirestore(doc);
              return _buildIncidentCard(context, incident, doc.id);
            },
            childCount: snapshot.data!.docs.length,
          )),
        );
      },
    );
  }

  Widget _buildIncidentCard(BuildContext context, IncidentModel incident, String docId) {
    final statusColor = _getStatusColor(incident.status);
    final statusLabel = _getStatusLabel(incident.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _getCategoryColor(incident.category).withValues(alpha:0.1), borderRadius: BorderRadius.circular(100)),
            child: Text(incident.category, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _getCategoryColor(incident.category))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha:0.1), borderRadius: BorderRadius.circular(100)),
            child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(incident.description, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Text('Lokasi: ${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400)),
        const SizedBox(height: 16),
        // KF5.2: Kemaskini status insiden
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => _showIncidentDetails(context, incident, docId),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('BUTIRAN'),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: () => _showStatusUpdateDialog(context, docId, incident.status),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('KEMASKINI', style: TextStyle(color: Colors.white)),
          )),
        ]),
      ]),
    );
  }

  /// KF5: Dialog kemaskini status - Diterima, Dalam Tindakan, Selesai
  void _showStatusUpdateDialog(BuildContext context, String docId, String currentStatus) {
    final notesController = TextEditingController();
    String selectedStatus = currentStatus;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kemaskini Status Insiden', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Text('STATUS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 2)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              _statusChip('received', 'Diterima', Colors.blue, selectedStatus, (v) => setModalState(() => selectedStatus = v)),
              _statusChip('responding', 'Dalam Tindakan', Colors.orange, selectedStatus, (v) => setModalState(() => selectedStatus = v)),
              _statusChip('resolved', 'Selesai', Colors.green, selectedStatus, (v) => setModalState(() => selectedStatus = v)),
            ]),
            const SizedBox(height: 20),
            Text('CATATAN', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 2)),
            const SizedBox(height: 8),
            TextField(controller: notesController, maxLines: 3, decoration: InputDecoration(hintText: 'Tambah catatan ringkas...', filled: true, fillColor: AppColors.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () async {
                final updateData = <String, dynamic>{'statusLaporan': selectedStatus};
                if (notesController.text.trim().isNotEmpty) updateData['notes'] = notesController.text.trim();
                await FirebaseFirestore.instance.collection(IncidentModel.collection).doc(docId).update(updateData);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status dikemaskini kepada: ${_getStatusLabel(selectedStatus)}'), backgroundColor: Colors.green));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('SIMPAN PERUBAHAN', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white)),
            )),
          ]),
        );
      }),
    );
  }

  Widget _statusChip(String value, String label, Color color, String selected, Function(String) onTap) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? color : color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: color, width: isSelected ? 0 : 1)),
        child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : color)),
      ),
    );
  }

  void _showIncidentDetails(BuildContext context, IncidentModel incident, String docId) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Butiran Insiden', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          _detailRow('Kategori', incident.category),
          _detailRow('Keutamaan', incident.priority),
          _detailRow('Status', _getStatusLabel(incident.status)),
          _detailRow('Keterangan', incident.description),
          _detailRow('Lokasi', '${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}'),
          _detailRow('Tarikh', '${incident.timestamp.day}/${incident.timestamp.month}/${incident.timestamp.year} ${incident.timestamp.hour}:${incident.timestamp.minute.toString().padLeft(2, '0')}'),
          if (incident.notes.isNotEmpty) _detailRow('Catatan', incident.notes),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500))),
        Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'SOS': return Colors.red;
      case 'MEDICAL': return Colors.blue;
      case 'FIRE': return Colors.orange;
      case 'THEFT': return Colors.purple;
      default: return AppColors.secondary;
    }
  }

  Color _getStatusColor(String s) {
    switch (s.toLowerCase()) { case 'resolved': return Colors.green; case 'responding': return Colors.orange; case 'received': return Colors.blue; default: return AppColors.primary; }
  }

  String _getStatusLabel(String s) {
    switch (s.toLowerCase()) { case 'resolved': return 'SELESAI'; case 'responding': return 'DALAM TINDAKAN'; case 'received': return 'DITERIMA'; default: return 'MENUNGGU'; }
  }
}


