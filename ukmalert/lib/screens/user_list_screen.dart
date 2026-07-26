import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';

class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Senarai Pengguna', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.onSurface)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Tiada pengguna direkodkan.',
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
              final doc = snapshot.data!.docs[index];
              final user = UserModel.fromFirestore(doc);
              return _buildUserCard(context, user);
            },
          );
        },
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, UserModel user) {
    Color roleColor = Colors.blue;
    if (user.isPegawaiKeselamatan) roleColor = Colors.red;
    if (user.isKakitangan) roleColor = Colors.orange;
    if (user.isAdmin) roleColor = Colors.purple;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.1),
          child: Icon(Icons.person, color: roleColor),
        ),
        title: Text(user.nama, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.emel, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                user.peranan.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: roleColor),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: () => _showEditRoleDialog(context, user),
        ),
      ),
    );
  }

  void _showEditRoleDialog(BuildContext context, UserModel user) {
    String selectedRole = user.peranan;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Kemaskini Peranan', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _roleOption(ctx, 'pelajar', 'Pelajar', selectedRole, (v) => setDialogState(() => selectedRole = v)),
              _roleOption(ctx, 'kakitangan', 'Kakitangan', selectedRole, (v) => setDialogState(() => selectedRole = v)),
              _roleOption(ctx, 'pegawai_keselamatan', 'Pegawai Keselamatan', selectedRole, (v) => setDialogState(() => selectedRole = v)),
              _roleOption(ctx, 'admin', 'Admin', selectedRole, (v) => setDialogState(() => selectedRole = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'peranan': selectedRole});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleOption(BuildContext context, String value, String label, String selected, ValueChanged<String> onChanged) {
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected == value ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected == value ? AppColors.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.inter(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
