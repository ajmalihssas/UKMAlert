import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/incident_model.dart';
import '../providers/user_provider.dart';

class ReportHistoryScreen extends StatelessWidget {
  const ReportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isGuest = userProvider.isGuest;

    // Use matric number if loaded, otherwise fall back to Firebase UID.
    // This handles the case where idPengguna is "" in Firestore but the user
    // is genuinely logged in.
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final idPengguna = userProvider.idPengguna;
    final queryId = idPengguna.isNotEmpty ? idPengguna : firebaseUid;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Sejarah Laporan',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: isGuest || queryId.isEmpty
          ? _emptyState(
              icon: Icons.person_off_outlined,
              message: 'Log masuk diperlukan untuk melihat sejarah laporan.',
            )
          : StreamBuilder<QuerySnapshot>(
              // No orderBy here — avoids composite index requirement.
              // Results are sorted client-side below.
              stream: FirebaseFirestore.instance
                  .collection(IncidentModel.collection)
                  .where('noMatriks', isEqualTo: queryId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (snapshot.hasError) {
                  return _emptyState(
                    icon: Icons.inbox_outlined,
                    message: 'Tiada laporan dihantar lagi.',
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _emptyState(
                    icon: Icons.inbox_outlined,
                    message: 'Tiada laporan dihantar lagi.',
                  );
                }

                // Sort by tarikhMasa descending client-side
                final docs = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = (aData['tarikhMasa'] as Timestamp?)
                            ?.toDate() ??
                        DateTime(0);
                    final bTime = (bData['tarikhMasa'] as Timestamp?)
                            ?.toDate() ??
                        DateTime(0);
                    return bTime.compareTo(aTime);
                  });

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final incident = IncidentModel.fromFirestore(docs[i]);
                    return _ReportCard(incident: incident);
                  },
                );
              },
            ),
    );
  }

  Widget _emptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Report card ────────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final IncidentModel incident;
  const _ReportCard({required this.incident});

  static const _statusConfig = {
    'resolved':   (label: 'Selesai',              color: AppColors.secondary),
    'responding': (label: 'Bantuan Dalam Perjalanan', color: Color(0xFFD97706)),
    'received':   (label: 'Diterima',             color: Color(0xFF2563EB)),
    'pending':    (label: 'Menunggu',              color: AppColors.primary),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig[incident.status.toLowerCase()] ??
        _statusConfig['pending']!;
    final statusColor = cfg.color;
    final statusLabel = cfg.label;

    final isSos = incident.category.toUpperCase() == 'SOS';
    final catColor = isSos ? AppColors.primary : AppColors.secondary;

    return GestureDetector(
      onTap: () => _showDetail(context, statusLabel, statusColor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Status colour strip
                Container(width: 4, color: statusColor),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category + status badge row
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
                                    ? incident.category.toUpperCase()
                                    : 'LAPORAN',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
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
                                statusLabel.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Description
                        Text(
                          incident.description.isNotEmpty
                              ? incident.description
                              : '(Tiada penerangan)',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Location + date
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 12,
                                color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                incident.locationName.isNotEmpty
                                    ? incident.locationName
                                    : '${incident.latitude.toStringAsFixed(4)}, '
                                        '${incident.longitude.toStringAsFixed(4)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm')
                                  .format(incident.timestamp),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),

                        // Officer notes (if any)
                        if (incident.notes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.shield_outlined,
                                    size: 13,
                                    color: AppColors.secondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    incident.notes,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.secondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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

  void _showDetail(
      BuildContext context, String statusLabel, Color statusColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        incident: incident,
        statusLabel: statusLabel,
        statusColor: statusColor,
      ),
    );
  }
}

// ── Detail bottom sheet ────────────────────────────────────────────────────────
class _DetailSheet extends StatelessWidget {
  final IncidentModel incident;
  final String statusLabel;
  final Color statusColor;
  const _DetailSheet({
    required this.incident,
    required this.statusLabel,
    required this.statusColor,
  });

  static const _steps = [
    ('pending',    'Menunggu',                   AppColors.primary),
    ('received',   'Diterima',                   Color(0xFF2563EB)),
    ('responding', 'Bantuan Dalam Perjalanan',   Color(0xFFD97706)),
    ('resolved',   'Selesai',                    AppColors.secondary),
  ];

  int get _currentStep {
    final idx = _steps.indexWhere(
        (s) => s.$1 == incident.status.toLowerCase());
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _currentStep;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm')
                            .format(incident.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    incident.category.isNotEmpty
                        ? incident.category.toUpperCase()
                        : 'LAPORAN',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    incident.description.isNotEmpty
                        ? incident.description
                        : '(Tiada penerangan)',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status tracker
                  _sectionLabel('STATUS LAPORAN'),
                  const SizedBox(height: 12),
                  ...List.generate(_steps.length, (i) {
                    final step = _steps[i];
                    final isDone = i <= currentStep;
                    final isActive = i == currentStep;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Circle + line
                        Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? step.$3.withValues(alpha: 0.12)
                                    : AppColors.surfaceContainerLow,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDone
                                      ? step.$3
                                      : AppColors.surfaceContainerHigh,
                                  width: isActive ? 2 : 1.5,
                                ),
                              ),
                              child: isDone
                                  ? Icon(
                                      i < currentStep
                                          ? Icons.check
                                          : Icons.radio_button_checked,
                                      color: step.$3,
                                      size: 14,
                                    )
                                  : null,
                            ),
                            if (i < _steps.length - 1)
                              Container(
                                width: 2,
                                height: 28,
                                color: i < currentStep
                                    ? _steps[i].$3.withValues(alpha: 0.3)
                                    : AppColors.surfaceContainerHigh,
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            step.$2,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isDone
                                  ? AppColors.onSurface
                                  : AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 24),

                  // Location
                  _sectionLabel('LOKASI'),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.location_on_outlined,
                    incident.locationName.isNotEmpty
                        ? incident.locationName
                        : '${incident.latitude.toStringAsFixed(5)}, '
                            '${incident.longitude.toStringAsFixed(5)}',
                  ),
                  const SizedBox(height: 20),

                  // Officer notes
                  if (incident.notes.isNotEmpty) ...[
                    _sectionLabel('MAKLUM BALAS PEGAWAI'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 16, color: AppColors.secondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              incident.notes,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.secondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Reference ID
                  _sectionLabel('ID RUJUKAN'),
                  const SizedBox(height: 8),
                  _infoRow(Icons.tag, incident.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurfaceVariant,
          letterSpacing: 1.5,
        ),
      );

  Widget _infoRow(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
}
