import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  static const List<String> _roles = [
    'pelajar',
    'kakitangan',
    'pegawai_keselamatan',
    'admin',
  ];

  static String _roleLabel(String r) {
    switch (r) {
      case 'kakitangan':
        return 'Kakitangan';
      case 'pegawai_keselamatan':
        return 'Pegawai Keselamatan';
      case 'admin':
        return 'Admin';
      default:
        return 'Pelajar';
    }
  }

  static Color _roleColor(String r) {
    switch (r) {
      case 'admin':
        return const Color(0xFF7C3AED);
      case 'pegawai_keselamatan':
        return kPrimary;
      case 'kakitangan':
        return kInfo;
      default:
        return kText3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Pengurusan Pengguna',
              style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kText1)),
          const SizedBox(height: 4),
          Text('Lihat dan ubah peranan pengguna berdaftar',
              style: GoogleFonts.inter(fontSize: 13, color: kText2)),
          const SizedBox(height: 24),

          // Users list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('nama')
                  .snapshots(),
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
                        Icon(Icons.people_outline,
                            color: kText3.withValues(alpha: 0.5),
                            size: 64),
                        const SizedBox(height: 12),
                        Text('Tiada pengguna berdaftar.',
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
                    final d = doc.data() as Map<String, dynamic>;
                    return _UserCard(
                      docId: doc.id,
                      nama: (d['nama'] ?? '-').toString(),
                      idPengguna:
                          (d['idPengguna'] ?? '-').toString(),
                      emel: (d['emel'] ?? '-').toString(),
                      peranan:
                          (d['peranan'] ?? 'pelajar').toString(),
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

  static Future<void> changeRole(
      BuildContext context, String docId, String currentRole) async {
    String selected = currentRole;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('Tukar Peranan',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kText1)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _roles.map((r) {
                final isSelected = selected == r;
                final color = _roleColor(r);
                return InkWell(
                  onTap: () => setS(() => selected = r),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.07)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? color : kBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Custom radio circle
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? color : kText3,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          _roleLabel(r),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected ? color : kText1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, color: kText2)),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(docId)
                    .update({'peranan': selected});
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Peranan dikemaskini kepada '
                          '${_roleLabel(selected)}'),
                      backgroundColor: kSuccess,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: kSurface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Simpan',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── User card ─────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final String docId, nama, idPengguna, emel, peranan;
  const _UserCard({
    required this.docId,
    required this.nama,
    required this.idPengguna,
    required this.emel,
    required this.peranan,
  });

  @override
  Widget build(BuildContext context) {
    final color = UsersScreen._roleColor(peranan);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          // Avatar circle with initial
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + ID
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kText1),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  idPengguna,
                  style:
                      GoogleFonts.inter(fontSize: 12, color: kText3),
                ),
              ],
            ),
          ),

          // Email
          Expanded(
            flex: 3,
            child: Text(
              emel,
              style: GoogleFonts.inter(fontSize: 13, color: kText2),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Role badge
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                UsersScreen._roleLabel(peranan),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Change role button
          OutlinedButton(
            onPressed: () =>
                UsersScreen.changeRole(context, docId, peranan),
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimary,
              side: const BorderSide(color: kPrimary),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Tukar Peranan',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
