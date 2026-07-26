import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/safe_zone_model.dart';

class ManageSafeZonesScreen extends StatelessWidget {
  const ManageSafeZonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Urus Zon Selamat', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.onSurface)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('safe_zones').orderBy('updatedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Tiada zon selamat direkodkan.',
                    style: GoogleFonts.inter(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final zone = SafeZoneModel.fromFirestore(snapshot.data!.docs[index]);
              return _buildZoneCard(context, zone);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddZoneDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildZoneCard(BuildContext context, SafeZoneModel zone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.tertiaryFixed,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.security, color: AppColors.onTertiaryFixed),
        ),
        title: Text(zone.name, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(zone.description, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text('Radius: ${zone.radius}m', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _showEditZoneDialog(context, zone);
            if (v == 'delete') _deleteZone(context, zone.id);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Kemaskini')),
            const PopupMenuItem(value: 'delete', child: Text('Padam')),
          ],
        ),
      ),
    );
  }

  void _showAddZoneDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lonCtrl = TextEditingController();
    final radCtrl = TextEditingController(text: '100');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tambah Zon Selamat', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: _inputDeco('Nama Lokasi')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: _inputDeco('Keterangan')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: latCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('Latitud'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: lonCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('Longitud'))),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: radCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('Radius (Meter)')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || latCtrl.text.isEmpty || lonCtrl.text.isEmpty) return;
                  await FirebaseFirestore.instance.collection('safe_zones').add({
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'latitude': double.parse(latCtrl.text),
                    'longitude': double.parse(lonCtrl.text),
                    'radius': double.parse(radCtrl.text),
                    'updatedAt': Timestamp.now(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('SIMPAN', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditZoneDialog(BuildContext context, SafeZoneModel zone) {
    final nameCtrl = TextEditingController(text: zone.name);
    final descCtrl = TextEditingController(text: zone.description);
    final latCtrl = TextEditingController(text: zone.latitude.toString());
    final lonCtrl = TextEditingController(text: zone.longitude.toString());
    final radCtrl = TextEditingController(text: zone.radius.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kemaskini Zon Selamat', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: _inputDeco('Nama Lokasi')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: _inputDeco('Keterangan')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: latCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('Latitud'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: lonCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('Longitud'))),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: radCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('Radius (Meter)')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('safe_zones').doc(zone.id).update({
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'latitude': double.parse(latCtrl.text),
                    'longitude': double.parse(lonCtrl.text),
                    'radius': double.parse(radCtrl.text),
                    'updatedAt': Timestamp.now(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('KEMASKINI', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteZone(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Padam Zon Selamat'),
        content: const Text('Adakah anda pasti ingin memadam zon selamat ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('safe_zones').doc(id).delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Padam', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}


