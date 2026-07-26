import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/safety_content_model.dart';

/// KF7: Paparan Kandungan Keselamatan (SOP & Panduan)
/// Mengambil data secara masa nyata daripada koleksi 'safety_content' di Firebase.
class SafetyGuideScreen extends StatelessWidget {
  const SafetyGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha:0.9),
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Panduan Keselamatan',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari protokol keselamatan...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Emergency Quick Tip Card
                  _buildQuickTipCard(),
                  const SizedBox(height: 32),

                  Text(
                    'SOP & Panduan Rasmi',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // KF7: Aliran data masa nyata daripada Firebase
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('safety_content').orderBy('updatedAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                )));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: _buildEmptyState(),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final content = SafetyContentModel.fromFirestore(doc);
                      return _buildSafetyItem(context, content);
                    },
                    childCount: snapshot.data!.docs.length,
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // Bottom Utilities
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildMapBanner(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildUtilCard(Icons.contact_phone, 'Talian Hot', AppColors.secondaryContainer, AppColors.onSecondaryContainer)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildUtilCard(Icons.my_location, 'Kongsi Lokasi', AppColors.surfaceContainerHighest, AppColors.onSurface)),
                    ],
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTipCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha:0.15),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.lightbulb,
              size: 100,
              color: Colors.white.withValues(alpha:0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'EMERGENCY QUICK TIP',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha:0.9),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Gunakan Aturan 3-3-3',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '3 minit tanpa udara, 3 hari tanpa air, 3 minggu tanpa makanan. Utamakan pernafasan dahulu.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha:0.8),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyItem(BuildContext context, SafetyContentModel content) {
    IconData icon;
    Color color;

    switch (content.category.toLowerCase()) {
      case 'sop':
        icon = Icons.assignment;
        color = AppColors.primary;
        break;
      case 'guideline':
        icon = Icons.help_outline;
        color = AppColors.secondary;
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            content.title,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            content.category.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                content.content,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          'Tiada kandungan keselamatan ditemui.',
          style: GoogleFonts.inter(color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildMapBanner() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: AppColors.inverseSurface,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.teal.shade200.withValues(alpha:0.5),
            AppColors.inverseSurface,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 16,
            right: 16,
            child: Icon(Icons.public, size: 80, color: Colors.white.withValues(alpha:0.1)),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peta Zon Selamat',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kenalpasti lokasi AED & Tempat Berkumpul',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha:0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilCard(IconData icon, String label, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}


