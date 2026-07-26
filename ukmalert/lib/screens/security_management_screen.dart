import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/safety_content_model.dart';
import '../models/notification_model.dart';
import 'manage_safe_zones_screen.dart';
import 'user_list_screen.dart';
import 'analytics_report_screen.dart';

/// KF7: Pengurusan Kandungan Keselamatan (Pentadbir Sistem)
class SecurityManagementScreen extends StatelessWidget {
  const SecurityManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text('Pengurusan Keselamatan', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.onSurface)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // System Controls
          _buildAdminSectionTitle('KAWALAN SISTEM'),
          const SizedBox(height: 16),
          _buildManagementCard(context, icon: Icons.notifications_active, title: 'Hantar Amaran Massa', subtitle: 'Hantar notifikasi kecemasan ke semua pengguna.', color: Colors.red, onTap: () => _showSendAlertDialog(context)),
          const SizedBox(height: 12),
          _buildManagementCard(context, icon: Icons.map, title: 'Urus Zon Selamat', subtitle: 'Kemaskini lokasi zon selamat di dalam kampus.', color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageSafeZonesScreen()))),
          const SizedBox(height: 32),
          // Safety Content CRUD - KF7.1
          _buildAdminSectionTitle('KANDUNGAN KESELAMATAN'),
          const SizedBox(height: 16),
          _buildSafetyContentList(context),
          const SizedBox(height: 32),
          // Data Management
          _buildAdminSectionTitle('PENGURUSAN DATA'),
          const SizedBox(height: 16),
          _buildManagementCard(context, icon: Icons.people, title: 'Senarai Pengguna', subtitle: 'Urus maklumat pelajar dan kakitangan.', color: AppColors.secondary, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListScreen()))),
          const SizedBox(height: 12),
          _buildManagementCard(context, icon: Icons.analytics, title: 'Laporan Analistik', subtitle: 'Analisis statistik insiden bulanan.', color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsReportScreen()))),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddContentDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// KF7: Senarai kandungan keselamatan dari Firebase
  Widget _buildSafetyContentList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('safety_content').orderBy('updatedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('Tiada kandungan keselamatan. Tekan + untuk menambah.', style: GoogleFonts.inter(color: Colors.grey.shade500), textAlign: TextAlign.center),
            ]),
          );
        }
        return Column(
          children: snapshot.data!.docs.map((doc) {
            final content = SafetyContentModel.fromFirestore(doc);
            return _buildContentCard(context, content);
          }).toList(),
        );
      },
    );
  }

  Widget _buildContentCard(BuildContext context, SafetyContentModel content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.secondaryFixed, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.article, color: AppColors.secondary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(content.title, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 2),
          Text(content.category.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.secondary, letterSpacing: 1)),
        ])),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _showEditContentDialog(context, content);
            if (v == 'delete') _deleteContent(context, content.id);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Kemaskini')),
            const PopupMenuItem(value: 'delete', child: Text('Padam')),
          ],
        ),
      ]),
    );
  }

  /// KF7: Tambah kandungan baharu
  void _showAddContentDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String selectedCat = 'sop';
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tambah Kandungan', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Tajuk', filled: true, fillColor: AppColors.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          TextField(controller: contentCtrl, maxLines: 4, decoration: InputDecoration(labelText: 'Kandungan', filled: true, fillColor: AppColors.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedCat,
            items: const [DropdownMenuItem(value: 'sop', child: Text('SOP')), DropdownMenuItem(value: 'guideline', child: Text('Panduan')), DropdownMenuItem(value: 'info', child: Text('Maklumat'))],
            onChanged: (v) => setModalState(() => selectedCat = v!),
            decoration: InputDecoration(labelText: 'Kategori', filled: true, fillColor: AppColors.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) { _showSnack(ctx, 'Sila isi semua medan.'); return; }
              await FirebaseFirestore.instance.collection('safety_content').add({'title': titleCtrl.text.trim(), 'content': contentCtrl.text.trim(), 'category': selectedCat, 'updatedAt': Timestamp.now()});
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) _showSnack(context, 'Kandungan berjaya ditambah!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text('SIMPAN', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white)),
          )),
        ]),
      )),
    );
  }

  void _showEditContentDialog(BuildContext context, SafetyContentModel content) {
    final titleCtrl = TextEditingController(text: content.title);
    final contentCtrl = TextEditingController(text: content.content);
    String selectedCat = content.category;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Kemaskini Kandungan', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Tajuk', filled: true, fillColor: AppColors.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          TextField(controller: contentCtrl, maxLines: 4, decoration: InputDecoration(labelText: 'Kandungan', filled: true, fillColor: AppColors.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: selectedCat, items: const [DropdownMenuItem(value: 'sop', child: Text('SOP')), DropdownMenuItem(value: 'guideline', child: Text('Panduan')), DropdownMenuItem(value: 'info', child: Text('Maklumat'))], onChanged: (v) => setModalState(() => selectedCat = v!), decoration: InputDecoration(labelText: 'Kategori', filled: true, fillColor: AppColors.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('safety_content').doc(content.id).update({'title': titleCtrl.text.trim(), 'content': contentCtrl.text.trim(), 'category': selectedCat, 'updatedAt': Timestamp.now()});
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) _showSnack(context, 'Kandungan berjaya dikemaskini!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text('KEMASKINI', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white)),
          )),
        ]),
      )),
    );
  }

  void _deleteContent(BuildContext context, String docId) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Padam Kandungan', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
      content: Text('Adakah anda pasti ingin memadam kandungan ini?', style: GoogleFonts.inter()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ElevatedButton(onPressed: () async { await FirebaseFirestore.instance.collection('safety_content').doc(docId).delete(); if (ctx.mounted) Navigator.pop(ctx); if (context.mounted) _showSnack(context, 'Kandungan berjaya dipadam.'); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('Padam', style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  /// Hantar amaran massa ke koleksi notifications
  void _showSendAlertDialog(BuildContext context) {
    final msgCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hantar Amaran Massa', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Tajuk Amaran', filled: true, fillColor: AppColors.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          TextField(controller: msgCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Mesej Amaran', filled: true, fillColor: AppColors.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || msgCtrl.text.trim().isEmpty) { _showSnack(ctx, 'Sila isi semua medan.'); return; }
              await FirebaseFirestore.instance.collection(NotificationModel.collection).add({'title': titleCtrl.text.trim(), 'mesej': msgCtrl.text.trim(), 'type': 'emergency', 'tarikhHantar': Timestamp.now(), 'status': false, 'noMatriks': ''});
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) _showSnack(context, 'Amaran massa berjaya dihantar!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text('HANTAR AMARAN', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white)),
          )),
        ]),
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16)));
  }

  Widget _buildAdminSectionTitle(String title) => Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 2));

  Widget _buildManagementCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
          ])),
          Icon(Icons.chevron_right, color: Colors.grey.shade300),
        ]),
      ),
    );
  }
}


