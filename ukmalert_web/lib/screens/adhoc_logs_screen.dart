import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import '../theme/app_theme.dart';

class AdhocLogsScreen extends StatefulWidget {
  const AdhocLogsScreen({super.key});
  @override
  State<AdhocLogsScreen> createState() => _AdhocLogsScreenState();
}

class _AdhocLogsScreenState extends State<AdhocLogsScreen> {
  String _actionFilter = 'semua';
  bool _showExplainer = true;

  static const List<(String, String, IconData)> _filters = [
    ('semua',         'Semua',           Icons.list_rounded),
    ('connected',     'Disambung',        Icons.link_rounded),
    ('disconnected',  'Terputus',         Icons.link_off_rounded),
    ('message_sent',  'Mesej Dihantar',   Icons.send_rounded),
  ];

  Stream<QuerySnapshot> _stream() {
    final base = FirebaseFirestore.instance
        .collection('adhoc_logs')
        .orderBy('timestamp', descending: true)
        .limit(200);
    if (_actionFilter == 'semua') return base.snapshots();
    return base.where('action', isEqualTo: _actionFilter).snapshots();
  }

  // ─── SOS detection ────────────────────────────────────────────────────────
  bool _isSos(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('sos') ||
        lower.contains('kecemasan') ||
        lower.contains('darurat') ||
        lower.contains('tolong') ||
        lower.contains('emergency') ||
        lower.contains('bahaya');
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'connected':    return kSuccess;
      case 'disconnected': return kWarning;
      case 'message_sent': return kPrimary;
      default:             return kText3;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'connected':    return Icons.link_rounded;
      case 'disconnected': return Icons.link_off_rounded;
      case 'message_sent': return Icons.send_rounded;
      default:             return Icons.circle;
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'connected':    return 'DISAMBUNG';
      case 'disconnected': return 'TERPUTUS';
      case 'message_sent': return 'MESEJ DIHANTAR';
      default:             return action.toUpperCase();
    }
  }

  // ─── Count helpers ────────────────────────────────────────────────────────
  Map<String, int> _counts(List<QueryDocumentSnapshot> docs) {
    int conn = 0, disc = 0, msgs = 0;
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      switch (data['action'] as String? ?? '') {
        case 'connected':    conn++; break;
        case 'disconnected': disc++; break;
        case 'message_sent': msgs++; break;
      }
    }
    return {'connected': conn, 'disconnected': disc, 'message_sent': msgs};
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('adhoc_logs')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, allSnap) {
        final allDocs = allSnap.data?.docs ?? [];
        final counts = _counts(allDocs);

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.wifi_tethering, color: kPrimary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Log Rangkaian Ad-Hoc',
                          style: GoogleFonts.inter(
                              fontSize: 22, fontWeight: FontWeight.w700, color: kText1)),
                      Text('Rekod sambungan & mesej SOS hop-to-hop peranti pengguna',
                          style: GoogleFonts.inter(fontSize: 13, color: kText2)),
                    ],
                  ),
                  const Spacer(),
                  // Toggle explainer button
                  TextButton.icon(
                    onPressed: () => setState(() => _showExplainer = !_showExplainer),
                    icon: Icon(_showExplainer ? Icons.visibility_off : Icons.info_outline,
                        size: 16, color: kPrimary),
                    label: Text(_showExplainer ? 'Sembunyikan Proses' : 'Tunjukkan Proses',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600, color: kPrimary)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Stats row ────────────────────────────────────────────────────
              Row(
                children: [
                  _StatCard(
                    icon: Icons.devices_rounded,
                    label: 'Jumlah Rekod',
                    value: allDocs.length.toString(),
                    color: kPrimary,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.link_rounded,
                    label: 'Sambungan',
                    value: counts['connected'].toString(),
                    color: kSuccess,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.send_rounded,
                    label: 'Mesej Dihantar',
                    value: counts['message_sent'].toString(),
                    color: kPrimary,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.link_off_rounded,
                    label: 'Terputus',
                    value: counts['disconnected'].toString(),
                    color: kWarning,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.sos_rounded,
                    label: 'Mesej SOS',
                    value: allDocs
                        .where((d) =>
                            (d.data() as Map<String, dynamic>)['action'] == 'message_sent' &&
                            _isSos((d.data() as Map<String, dynamic>)['message'] as String? ?? ''))
                        .length
                        .toString(),
                    color: kDanger,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Process explainer ────────────────────────────────────────────
              if (_showExplainer) ...[
                _AdHocProcessExplainer(),
                const SizedBox(height: 20),
              ],

              // ── Filter chips ─────────────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((f) {
                    final isActive = _actionFilter == f.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _actionFilter = f.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: isActive ? kPrimary : kSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isActive ? kPrimary : kBorder),
                          boxShadow: isActive ? kCardShadow : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(f.$3,
                                size: 14,
                                color: isActive ? Colors.white : kText2),
                            const SizedBox(width: 6),
                            Text(f.$2,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? Colors.white : kText2,
                                )),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Log list ──────────────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _stream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: kPrimary));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _EmptyState(filter: _actionFilter);
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        return _LogCard(
                          data: d,
                          actionColor: _actionColor(d['action'] as String? ?? ''),
                          actionIcon: _actionIcon(d['action'] as String? ?? ''),
                          actionLabel: _actionLabel(d['action'] as String? ?? ''),
                          isSos: _isSos(d['message'] as String? ?? ''),
                          onMapTap: (url) => html.window.open(url, '_blank'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Stat summary card ──────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
          boxShadow: kCardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: kText2)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ad-Hoc Process Explainer ───────────────────────────────────────────────
class _AdHocProcessExplainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF001A45), const Color(0xFF003DA5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.route_rounded, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Text('CARA MESEJ SOS / KECEMASAN DIHANTAR SECARA OFFLINE',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.greenAccent,
                      letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),

          // Process steps (horizontal)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProcessStep(
                  stepNum: '1',
                  icon: Icons.wifi_off_rounded,
                  title: 'Internet Terputus',
                  desc: 'Pengguna tiada capaian internet (bencana, kawasan terpencil)',
                  color: Colors.orangeAccent,
                ),
                _ProcessArrow(),
                _ProcessStep(
                  stepNum: '2',
                  icon: Icons.wifi_tethering_rounded,
                  title: 'Aktifkan Ad-Hoc',
                  desc: 'Peranti A mengaktifkan mod Ad-Hoc melalui Wi-Fi Direct & Bluetooth Mesh',
                  color: Colors.blueAccent,
                ),
                _ProcessArrow(),
                _ProcessStep(
                  stepNum: '3',
                  icon: Icons.sos_rounded,
                  title: 'Hantar Mesej SOS',
                  desc: 'Pengguna menaip & menghantar mesej kecemasan ke semua peranti berdekatan',
                  color: Colors.redAccent,
                ),
                _ProcessArrow(),
                _ProcessStep(
                  stepNum: '4',
                  icon: Icons.device_hub_rounded,
                  title: 'Ulang-Alik Hop',
                  desc: 'Setiap peranti yang menerima mesej menghantar semula ke peranti lain (relay)',
                  color: Colors.purpleAccent,
                ),
                _ProcessArrow(),
                _ProcessStep(
                  stepNum: '5',
                  icon: Icons.cloud_upload_rounded,
                  title: 'Log ke Firebase',
                  desc: 'Apabila ada internet semula, log hop dihantar ke pelayan & muncul di sini',
                  color: Colors.greenAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legend row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _LegendItem(
                  color: kSuccess,
                  icon: Icons.link_rounded,
                  label: 'DISAMBUNG — peranti berjaya bergabung dalam mesh'),
              _LegendItem(
                  color: kWarning,
                  icon: Icons.link_off_rounded,
                  label: 'TERPUTUS — peranti keluar dari mesh'),
              _LegendItem(
                  color: kPrimary,
                  icon: Icons.send_rounded,
                  label: 'MESEJ DIHANTAR — mesej berjaya direlai ke hop seterusnya'),
              _LegendItem(
                  color: kDanger,
                  icon: Icons.sos_rounded,
                  label: 'SOS — mesej kecemasan kritikal'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProcessStep extends StatelessWidget {
  final String stepNum;
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _ProcessStep(
      {required this.stepNum,
      required this.icon,
      required this.title,
      required this.desc,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        children: [
          // Icon circle
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Center(
                      child: Text(stepNum,
                          style: GoogleFonts.inter(
                              fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text(desc,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.65),
                  height: 1.4)),
        ],
      ),
    );
  }
}

class _ProcessArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Icon(Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.3), size: 28),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _LegendItem(
      {required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 5),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85))),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Individual Log Card ─────────────────────────────────────────────────────
class _LogCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color actionColor;
  final IconData actionIcon;
  final String actionLabel;
  final bool isSos;
  final void Function(String url) onMapTap;

  const _LogCard({
    required this.data,
    required this.actionColor,
    required this.actionIcon,
    required this.actionLabel,
    required this.isSos,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final action = data['action'] as String? ?? '';
    final from = data['fromDevice'] as String? ?? '-';
    final to = data['toDevice'] as String? ?? '-';
    final msg = data['message'] as String? ?? '';
    final mapsUrl = data['mapsUrl'] as String?;
    final lat = data['latitude'];
    final lng = data['longitude'];
    final ts = (data['timestamp'] as Timestamp?)?.toDate();
    final timeStr = ts != null
        ? DateFormat('dd MMM yyyy, HH:mm:ss').format(ts)
        : '-';

    final isMessage = action == 'message_sent';
    final cardBorder = isSos
        ? Border.all(color: kDanger, width: 2)
        : Border.all(color: kBorder);
    final cardColor = isSos
        ? kDanger.withValues(alpha: 0.04)
        : kSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: cardBorder,
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header bar ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSos
                  ? kDanger.withValues(alpha: 0.08)
                  : actionColor.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                // Action badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: actionColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(actionIcon, color: actionColor, size: 13),
                      const SizedBox(width: 6),
                      Text(actionLabel,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: actionColor,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
                if (isSos) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kDanger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sos_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text('MESEJ KECEMASAN',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                // Timestamp
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 12, color: kText3),
                    const SizedBox(width: 4),
                    Text(timeStr,
                        style: GoogleFonts.inter(fontSize: 11, color: kText3)),
                  ],
                ),
              ],
            ),
          ),

          // ── Card body ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device hop row: FROM → TO
                Row(
                  children: [
                    _DeviceChip(name: from, icon: Icons.phone_android_rounded, color: kPrimary),
                    const SizedBox(width: 8),
                    // Animated arrow
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 2,
                              color: actionColor.withValues(alpha: 0.4),
                            ),
                            Icon(Icons.arrow_forward_rounded,
                                color: actionColor, size: 16),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('hop', style: GoogleFonts.inter(fontSize: 9, color: kText3)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    _DeviceChip(name: to, icon: Icons.phone_android_rounded, color: kText2),
                    const Spacer(),
                    // Location
                    if (mapsUrl != null)
                      InkWell(
                        onTap: () => onMapTap(mapsUrl),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kDanger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: kDanger.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  color: kDanger, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                lat != null
                                    ? '${(lat as double).toStringAsFixed(4)}, ${(lng as double).toStringAsFixed(4)}'
                                    : 'Lihat GPS',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: kDanger,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off_rounded,
                                size: 13, color: kText3),
                            const SizedBox(width: 4),
                            Text('Tiada GPS',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: kText3)),
                          ],
                        ),
                      ),
                  ],
                ),

                // Message content (only for message_sent)
                if (isMessage && msg.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSos
                          ? kDanger.withValues(alpha: 0.06)
                          : kPrimaryLt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSos
                              ? kDanger.withValues(alpha: 0.25)
                              : kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSos
                                  ? Icons.warning_amber_rounded
                                  : Icons.chat_bubble_outline_rounded,
                              size: 13,
                              color: isSos ? kDanger : kText2,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isSos ? 'ISI MESEJ KECEMASAN (AD-HOC OFFLINE)' : 'ISI MESEJ',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isSos ? kDanger : kText2,
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(msg,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: isSos ? FontWeight.w700 : FontWeight.w500,
                                color: isSos ? kDanger : kText1,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ],

                // Relay info footer for message events
                if (isMessage) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.device_hub_rounded, size: 12, color: kText3),
                      const SizedBox(width: 5),
                      Text(
                        'Mesej ini direlai secara berperingkat (hop-to-hop) melalui rangkaian mesh tanpa internet.',
                        style: GoogleFonts.inter(fontSize: 10, color: kText3, height: 1.4),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Device chip ─────────────────────────────────────────────────────────────
class _DeviceChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  const _DeviceChip(
      {required this.name, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(name,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kPrimaryLt,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wifi_off_rounded, size: 36, color: kText3.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Text('Tiada log Ad-Hoc buat masa ini',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700, color: kText1)),
          const SizedBox(height: 6),
          Text(
            filter == 'semua'
                ? 'Log akan muncul apabila pengguna menyambung atau menghantar mesej melalui mod Ad-Hoc.'
                : 'Tiada rekod untuk penapis "$filter" buat masa ini.',
            style: GoogleFonts.inter(fontSize: 13, color: kText2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: kPrimaryLt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: kPrimary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pengguna perlu membuka skrin "Rangkaian Ad-Hoc" pada aplikasi Android untuk mengaktifkan mod ini.',
                    style: GoogleFonts.inter(fontSize: 12, color: kText1, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
