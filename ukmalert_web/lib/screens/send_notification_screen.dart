import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../models/notification_model.dart';

// FCM Server Key — Firebase Console → Project Settings → Cloud Messaging → Server key
const String _fcmServerKey = 'YOUR_FCM_SERVER_KEY_HERE';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() =>
      _SendNotificationScreenState();
}

class _SendNotificationScreenState
    extends State<SendNotificationScreen> {
  final _titleCtrl  = TextEditingController();
  final _msgCtrl    = TextEditingController();
  final _targetCtrl = TextEditingController();
  String _type      = 'emergency';
  bool   _broadcast = true;
  bool   _sending   = false;

  static const List<(String, String, Color, IconData)> _types = [
    ('emergency', 'EMERGENCY',          kDanger,  Icons.emergency_outlined),
    ('update',    'KEMASKINI',           kWarning, Icons.update_outlined),
    ('campus',    'KAMPUS',              kInfo,    Icons.campaign_outlined),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  /// Sends an FCM push notification via the Legacy HTTP API.
  /// Topic 'ukmalert_broadcast' reaches all subscribed devices.
  /// Topic `user_{id}` reaches a specific user who subscribed on login.
  Future<void> _sendFcmPush({
    required String title,
    required String body,
    required String topic,
  }) async {
    if (_fcmServerKey == 'YOUR_FCM_SERVER_KEY_HERE') return; // not configured yet
    try {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_fcmServerKey',
        },
        body: jsonEncode({
          'to': '/topics/$topic',
          'notification': {'title': title, 'body': body},
          'data': {'type': _type},
        }),
      );
    } catch (e) {
      debugPrint('FCM push error: $e');
    }
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila isi tajuk dan mesej.')),
      );
      return;
    }
    if (!_broadcast && _targetCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila masukkan No. Matrik penerima.')),
      );
      return;
    }
    setState(() => _sending = true);
    final title   = _titleCtrl.text.trim();
    final message = _msgCtrl.text.trim();
    final targetId = _targetCtrl.text.trim();
    try {
      // 1. Write to Firestore — in-app real-time display
      final notif = NotificationModel(
        id: '',
        title: title,
        message: message,
        type: _type,
        timestamp: DateTime.now(),
        isRead: false,
        targetUserId: _broadcast ? '' : targetId,
      );
      await FirebaseFirestore.instance
          .collection(NotificationModel.collection)
          .add(notif.toFirestore());

      // 2. Send FCM push — reaches background/closed devices
      await _sendFcmPush(
        title: title,
        body: message,
        topic: _broadcast ? 'ukmalert_broadcast' : 'user_$targetId',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _broadcast
                ? 'Notifikasi berjaya dihantar kepada semua pengguna.'
                : 'Notifikasi berjaya dihantar kepada $targetId.',
          ),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _titleCtrl.clear();
      _msgCtrl.clear();
      _targetCtrl.clear();
      setState(() => _sending = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghantar: $e'), backgroundColor: kDanger),
      );
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Form card ────────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: kCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hantar Notifikasi',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: kText1)),
                  const SizedBox(height: 4),
                  Text(
                    'Notifikasi akan dipaparkan dalam aplikasi '
                    'pengguna secara masa nyata.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: kText2),
                  ),
                  const SizedBox(height: 28),

                  // Type chips
                  _sectionLabel('JENIS NOTIFIKASI'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((t) {
                      final active = _type == t.$1;
                      return GestureDetector(
                        onTap: () => setState(() => _type = t.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: active
                                ? t.$3
                                : t.$3.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: t.$3,
                                width: active ? 0 : 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(t.$4,
                                  size: 15,
                                  color: active
                                      ? Colors.white
                                      : t.$3),
                              const SizedBox(width: 6),
                              Text(t.$2,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? Colors.white
                                        : t.$3,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Target toggle
                  _sectionLabel('PENERIMA'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _toggleChip('Semua Pengguna', _broadcast,
                          () => setState(() => _broadcast = true)),
                      const SizedBox(width: 8),
                      _toggleChip('Pengguna Tertentu', !_broadcast,
                          () => setState(() => _broadcast = false)),
                    ],
                  ),
                  if (!_broadcast) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _targetCtrl,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: kText1),
                      decoration: _inputDeco(
                          'No. Matrik (cth: A204021)',
                          Icons.person_outline),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Title
                  _sectionLabel('TAJUK'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleCtrl,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: kText1),
                    decoration: _inputDeco(
                        'cth: Amaran Kecemasan Kampus',
                        Icons.title_outlined),
                  ),
                  const SizedBox(height: 16),

                  // Message
                  _sectionLabel('MESEJ'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _msgCtrl,
                    maxLines: 4,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: kText1),
                    decoration: _inputDeco(
                      'Tuliskan mesej notifikasi di sini...',
                      Icons.message_outlined,
                    ).copyWith(alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _sending ? 'Menghantar...' : 'Hantar Notifikasi',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: kSurface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),

          // ── History card ─────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: kCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dihantar Baru-baru Ini',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: kText1)),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(NotificationModel.collection)
                        .orderBy('tarikhHantar', descending: true)
                        .limit(20)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: kPrimary));
                      }
                      if (snapshot.data!.docs.isEmpty) {
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                                'Belum ada notifikasi dihantar.',
                                style: GoogleFonts.inter(
                                    color: kText3, fontSize: 13)),
                          ),
                        );
                      }
                      return SizedBox(
                        height: 520,
                        child: ListView.separated(
                          itemCount: snapshot.data!.docs.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: kBorder),
                          itemBuilder: (context, i) {
                            final notif =
                                NotificationModel.fromFirestore(
                                    snapshot.data!.docs[i]);
                            return _NotifHistoryTile(notif: notif);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kText3,
          letterSpacing: 1.5,
        ),
      );

  Widget _toggleChip(
      String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? kPrimary : kPrimaryLt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? kPrimary : kBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : kText2,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: kText3, fontSize: 13),
        prefixIcon: Icon(icon, color: kText3, size: 18),
        filled: true,
        fillColor: kBg,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: kPrimary, width: 1.5)),
      );
}

// ── Notification history tile ─────────────────────────────────────────────────
class _NotifHistoryTile extends StatelessWidget {
  final NotificationModel notif;
  const _NotifHistoryTile({required this.notif});

  @override
  Widget build(BuildContext context) {
    final typeColor = notif.type == 'emergency'
        ? kDanger
        : notif.type == 'update'
            ? kWarning
            : kInfo;

    final typeIcon = notif.type == 'emergency'
        ? Icons.emergency_outlined
        : notif.type == 'update'
            ? Icons.update_outlined
            : Icons.campaign_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, color: typeColor, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kText1),
                ),
                const SizedBox(height: 2),
                Text(
                  notif.targetUserId.isEmpty
                      ? 'Semua pengguna  ·  ${_fmtTime(notif.timestamp)}'
                      : '${notif.targetUserId}  ·  '
                          '${_fmtTime(notif.timestamp)}',
                  style:
                      GoogleFonts.inter(fontSize: 11, color: kText3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m lepas';
    if (d.inHours < 24) return '${d.inHours}j lepas';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
