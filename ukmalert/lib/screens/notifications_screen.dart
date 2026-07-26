import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/notification_model.dart';
import '../providers/user_provider.dart';

/// KF3: Menerima notifikasi keselamatan dari Firebase
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['SEMUA', 'EMERGENCY', 'UPDATES', 'CAMPUS'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha:0.9), elevation: 0, scrolledUnderElevation: 1,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
        title: Text('Notifikasi', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.onSurface)),
        actions: [
          TextButton(onPressed: _markAllAsRead, child: Text('Tanda semua dibaca', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary))),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedFilter == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(100)),
                      child: Text(_filters[index], style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.onSurfaceVariant, letterSpacing: 0.5)),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Notifications from Firebase
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                // Combine Firebase data with fallback static data
                List<Widget> notificationWidgets = [];

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  for (var doc in snapshot.data!.docs) {
                    final notif = NotificationModel.fromFirestore(doc);
                    notificationWidgets.add(_buildFirebaseNotificationCard(notif, doc.id));
                    notificationWidgets.add(const SizedBox(height: 12));
                  }
                }

                // Add static fallback notifications for demo
                if (notificationWidgets.isEmpty || _selectedFilter == 0) {
                  notificationWidgets.addAll(_buildStaticNotifications());
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  children: notificationWidgets,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    // Determine this user's ID — either matric number or Firebase UID
    final userProvider = context.read<UserProvider>();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final myId = userProvider.idPengguna.isNotEmpty
        ? userProvider.idPengguna
        : (firebaseUser?.uid ?? '');

    // Show broadcasts (noMatriks == '') AND notifications targeted to this user
    Query query = FirebaseFirestore.instance
        .collection(NotificationModel.collection)
        .where('noMatriks', whereIn: ['', myId])
        .orderBy('tarikhHantar', descending: true);

    if (_selectedFilter == 1) {
      query = query.where('type', isEqualTo: 'emergency');
    } else if (_selectedFilter == 2) {
      query = query.where('type', isEqualTo: 'update');
    } else if (_selectedFilter == 3) {
      query = query.where('type', isEqualTo: 'campus');
    }

    return query.snapshots();
  }

  void _markAllAsRead() async {
    final batch = FirebaseFirestore.instance.batch();
    final docs = await FirebaseFirestore.instance.collection(NotificationModel.collection).where('status', isEqualTo: false).get();
    for (var doc in docs.docs) { batch.update(doc.reference, {'status': true}); }
    await batch.commit();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Semua notifikasi ditanda sebagai dibaca'), behavior: SnackBarBehavior.floating));
  }

  Widget _buildFirebaseNotificationCard(NotificationModel notif, String docId) {
    IconData icon; Color iconBgColor, iconColor, accentColor, labelColor;
    String label;
    switch (notif.type) {
      case 'emergency': icon = Icons.emergency; iconBgColor = AppColors.errorContainer; iconColor = AppColors.primary; accentColor = AppColors.primary; labelColor = AppColors.primary; label = 'EMERGENCY ALERT'; break;
      case 'update': icon = Icons.warning; iconBgColor = AppColors.tertiaryFixed; iconColor = AppColors.onTertiaryFixed; accentColor = AppColors.tertiaryContainer; labelColor = AppColors.tertiaryContainer; label = 'INCIDENT UPDATE'; break;
      default: icon = Icons.campaign; iconBgColor = AppColors.secondaryFixed; iconColor = AppColors.onSecondaryContainer; accentColor = AppColors.secondaryContainer; labelColor = AppColors.secondary; label = 'CAMPUS ANNOUNCEMENT';
    }
    return _buildNotificationCard(icon: icon, iconBgColor: iconBgColor, iconColor: iconColor, accentColor: accentColor, label: label, labelColor: labelColor, time: _formatTime(notif.timestamp), title: notif.title, body: notif.message, isRead: notif.isRead);
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} MINIT LEPAS';
    if (diff.inHours < 24) return '${diff.inHours} JAM LEPAS';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  List<Widget> _buildStaticNotifications() {
    return [
      _buildNotificationCard(icon: Icons.emergency, iconBgColor: AppColors.errorContainer, iconColor: AppColors.primary, accentColor: AppColors.primary, label: 'EMERGENCY ALERT', labelColor: AppColors.primary, time: 'SEKARANG', title: 'Evakuasi Bangunan: Blok A', body: 'Kebocoran gas dikesan di tingkat 3 Blok A. Sila tinggalkan bangunan melalui tangga keselamatan dengan segera.'),
      const SizedBox(height: 12),
      _buildNotificationCard(icon: Icons.warning, iconBgColor: AppColors.tertiaryFixed, iconColor: AppColors.onTertiaryFixed, accentColor: AppColors.tertiaryContainer, label: 'INCIDENT UPDATE', labelColor: AppColors.tertiaryContainer, time: '2 JAM LEPAS', title: 'Penutupan Laluan Utama', body: 'Laluan berdekatan Pusanika ditutup sementara bagi kerja-kerja pembersihan pokok tumbang.'),
      const SizedBox(height: 12),
      _buildNotificationCard(icon: Icons.campaign, iconBgColor: AppColors.secondaryFixed, iconColor: AppColors.onSecondaryContainer, accentColor: AppColors.secondaryContainer, label: 'CAMPUS ANNOUNCEMENT', labelColor: AppColors.secondary, time: 'HARI INI, 09:15', title: 'Pendaftaran Kolej Kediaman', body: 'Sistem pendaftaran kolej kediaman untuk semester hadapan akan dibuka pada 15 Oktober ini.', isRead: true),
      const SizedBox(height: 12),
      _buildNotificationCard(icon: Icons.medical_services, iconBgColor: AppColors.errorContainer, iconColor: AppColors.primary, accentColor: AppColors.primary, label: 'EMERGENCY ALERT', labelColor: AppColors.primary, time: 'SEMALAM', title: 'Keperluan Penderma Darah', body: 'Unit Kesihatan UKM memerlukan penderma darah jenis O+ dengan segera.'),
    ];
  }

  Widget _buildNotificationCard({required IconData icon, required Color iconBgColor, required Color iconColor, required Color accentColor, required String label, required Color labelColor, required String time, required String title, required String body, bool isRead = false}) {
    return Opacity(
      opacity: isRead ? 0.7 : 1.0,
      child: Container(
        decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Stack(children: [
          Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 6, decoration: BoxDecoration(color: accentColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24))))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: iconColor, size: 22)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: labelColor, letterSpacing: 2)),
                  Text(time, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant.withValues(alpha:0.6))),
                ]),
                const SizedBox(height: 4),
                Text(title, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                const SizedBox(height: 4),
                Text(body, style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.5)),
              ])),
            ]),
          ),
        ]),
      ),
    );
  }
}


