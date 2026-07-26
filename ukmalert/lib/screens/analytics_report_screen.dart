import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/incident_model.dart';

class AnalyticsReportScreen extends StatelessWidget {
  const AnalyticsReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Laporan Analitik', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.onSurface)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(IncidentModel.collection).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Tiada data insiden untuk dianalisis.', style: GoogleFonts.inter(color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          final total = docs.length;
          
          // Basic analytics
          Map<String, int> catCounts = {};
          Map<String, int> statusCounts = {};
          
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final cat = (data['category'] ?? 'OTHER').toString().toUpperCase();
            final status = (data['status'] ?? 'pending').toString().toLowerCase();
            
            catCounts[cat] = (catCounts[cat] ?? 0) + 1;
            statusCounts[status] = (statusCounts[status] ?? 0) + 1;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(total),
                const SizedBox(height: 24),
                _buildSectionTitle('KATEGORI INSIDEN'),
                const SizedBox(height: 16),
                ...catCounts.entries.map((e) => _buildStatBar(e.key, e.value, total, _getCatColor(e.key))),
                const SizedBox(height: 32),
                _buildSectionTitle('STATUS PENYELESAIAN'),
                const SizedBox(height: 16),
                _buildStatusRow(statusCounts),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryContainer]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha:0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text('Jumlah Keseluruhan Insiden', style: GoogleFonts.inter(color: Colors.white.withValues(alpha:0.8), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text('$total', style: GoogleFonts.manrope(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 2));

  Widget _buildStatBar(String label, int count, int total, Color color) {
    double percent = total > 0 ? count / total : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('$count (${(percent * 100).toStringAsFixed(1)}%)', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(value: percent, backgroundColor: color.withValues(alpha:0.1), valueColor: AlwaysStoppedAnimation(color), minHeight: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(Map<String, int> statusCounts) {
    return Row(
      children: [
        _statusMiniCard('MENUNGGU', statusCounts['pending'] ?? 0, AppColors.primary),
        const SizedBox(width: 12),
        _statusMiniCard('TINDAKAN', statusCounts['responding'] ?? 0, Colors.orange),
        const SizedBox(width: 12),
        _statusMiniCard('SELESAI', statusCounts['resolved'] ?? 0, Colors.green),
      ],
    );
  }

  Widget _statusMiniCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha:0.2))),
        child: Column(
          children: [
            Text('$count', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Color _getCatColor(String cat) {
    switch (cat) {
      case 'SOS': return Colors.red;
      case 'MEDICAL': return Colors.blue;
      case 'FIRE': return Colors.orange;
      case 'THEFT': return Colors.purple;
      default: return AppColors.secondary;
    }
  }
}


