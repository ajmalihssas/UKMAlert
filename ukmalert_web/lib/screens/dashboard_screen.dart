import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import '../theme/app_theme.dart';
import '../models/incident_model.dart';
import 'incidents_screen.dart';

class DashboardScreen extends StatelessWidget {
  final String peranan;
  const DashboardScreen({super.key, required this.peranan});

  @override
  Widget build(BuildContext context) {
    final now = DateFormat('EEEE, d MMMM yyyy', 'ms').format(DateTime.now());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Papan Pemuka',
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: kText1)),
                  Text('Pusat Kawalan Keselamatan UKM',
                      style: GoogleFonts.inter(fontSize: 13, color: kText2)),
                ],
              ),
              const Spacer(),
              Text(now, style: GoogleFonts.inter(fontSize: 13, color: kText3)),
            ],
          ),
          const SizedBox(height: 24),

          // Stat cards
          _StatsRow(),
          const SizedBox(height: 24),

          // Map + SOS column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Incident Map (left, wider)
              Expanded(flex: 7, child: _LiveIncidentMap()),
              const SizedBox(width: 20),
              // SOS alerts (right)
              Expanded(flex: 3, child: _SosAlerts()),
            ],
          ),
          const SizedBox(height: 20),

          // Recent incidents (full width)
          _RecentIncidents(peranan: peranan),
        ],
      ),
    );
  }
}

// ── Stat cards ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(IncidentModel.collection).snapshots(),
      builder: (context, snapshot) {
        int pending = 0, responding = 0, resolved = 0, total = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final s = (d['statusLaporan'] ?? d['status'] ?? 'pending').toString();
            total++;
            switch (s.toLowerCase()) {
              case 'resolved':   resolved++; break;
              case 'responding': responding++; break;
              default:           pending++; break;
            }
          }
        }
        return Row(children: [
          _StatCard(label: 'MENUNGGU',       value: pending,    color: kDanger,  icon: Icons.hourglass_empty_outlined),
          const SizedBox(width: 16),
          _StatCard(label: 'DALAM TINDAKAN', value: responding, color: kWarning, icon: Icons.directions_run_outlined),
          const SizedBox(width: 16),
          _StatCard(label: 'SELESAI',        value: resolved,   color: kSuccess, icon: Icons.check_circle_outline),
          const SizedBox(width: 16),
          _StatCard(label: 'JUMLAH',         value: total,      color: kPrimary, icon: Icons.list_alt_outlined),
        ]);
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), boxShadow: kCardShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text('$value', style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: kText3, letterSpacing: 1.5)),
        ]),
      ),
    );
  }
}

// ── Live Incident Map ──────────────────────────────────────────────────────────
class _LiveIncidentMap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.map_rounded, color: kPrimary, size: 18),
                const SizedBox(width: 8),
                Text('Peta Insiden Langsung',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600, color: kText1)),
                const Spacer(),
                _legend(kDanger, 'SOS'),
                const SizedBox(width: 12),
                _legend(kWarning, 'Kebakaran'),
                const SizedBox(width: 12),
                _legend(kInfo, 'Perubatan'),
              ],
            ),
          ),
          // Interactive map with real-time incident markers
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(IncidentModel.collection)
                .where('statusLaporan', whereNotIn: ['resolved'])
                .snapshots(),
            builder: (context, snapshot) {
              final markers = <Marker>[];
              if (snapshot.hasData) {
                for (final doc in snapshot.data!.docs) {
                  final inc = IncidentModel.fromFirestore(doc);
                  markers.add(Marker(
                    point: LatLng(inc.latitude, inc.longitude),
                    width: 36,
                    height: 36,
                    child: _IncidentPin(category: inc.category),
                  ));
                }
              }
              return SizedBox(
                height: 340,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(2.9277, 101.7809),
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.ukmalert_web',
                      ),
                      if (markers.isNotEmpty) MarkerLayer(markers: markers),
                    ],
                  ),
                ),
              );
            },
          ),
          // Location count chips
          _LocationStats(),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: kText3)),
      ]);
}

// ── Incident pin marker ────────────────────────────────────────────────────────
class _IncidentPin extends StatelessWidget {
  final String category;
  const _IncidentPin({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)
        ],
      ),
      child: Icon(_icon(), color: Colors.white, size: 18),
    );
  }

  Color _color() {
    switch (category.toUpperCase()) {
      case 'SOS':
        return kDanger;
      case 'FIRE':
      case 'KEBAKARAN':
        return kWarning;
      case 'MEDICAL':
      case 'PERUBATAN':
        return kInfo;
      case 'THEFT':
      case 'KECURIAN':
        return const Color(0xFF8B5CF6);
      case 'ACCIDENT':
      case 'KEMALANGAN':
        return Colors.orange;
      default:
        return kPrimary;
    }
  }

  IconData _icon() {
    switch (category.toUpperCase()) {
      case 'SOS':
        return Icons.sos;
      case 'FIRE':
      case 'KEBAKARAN':
        return Icons.local_fire_department;
      case 'MEDICAL':
      case 'PERUBATAN':
        return Icons.medical_services;
      case 'THEFT':
      case 'KECURIAN':
        return Icons.security;
      case 'ACCIDENT':
      case 'KEMALANGAN':
        return Icons.car_crash;
      default:
        return Icons.report;
    }
  }
}

// ── Location-based incident stats ─────────────────────────────────────────────
class _LocationStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(IncidentModel.collection)
          .where('statusLaporan', whereNotIn: ['resolved'])
          .snapshots(),
      builder: (context, snapshot) {
        final locationCounts = <String, int>{};
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final loc = (d['alamat'] ?? d['locationName'] ?? 'Tidak Diketahui').toString();
            final shortLoc = loc.length > 40 ? '${loc.substring(0, 37)}...' : loc;
            locationCounts[shortLoc] = (locationCounts[shortLoc] ?? 0) + 1;
          }
        }

        if (locationCounts.isEmpty) return const SizedBox.shrink();

        final sorted = locationCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top = sorted.take(4).toList();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lokasi Aktif (Belum Selesai)',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: kText2)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: top.map((e) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: kDanger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kDanger.withValues(alpha: 0.2)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_on, color: kDanger, size: 12),
                    const SizedBox(width: 4),
                    Text(e.key, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: kDanger)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: kDanger, borderRadius: BorderRadius.circular(10)),
                      child: Text('${e.value}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ]),
                )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Recent incidents card ──────────────────────────────────────────────────────
class _RecentIncidents extends StatelessWidget {
  final String peranan;
  const _RecentIncidents({required this.peranan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), boxShadow: kCardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.assignment_outlined, color: kPrimary, size: 18),
            const SizedBox(width: 8),
            Text('Laporan Terkini',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: kText1)),
          ]),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(IncidentModel.collection)
                .orderBy('tarikhMasa', descending: true)
                .limit(8)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: kPrimary)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Tiada laporan buat masa ini.', style: GoogleFonts.inter(fontSize: 13, color: kText3))),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final i = IncidentModel.fromFirestore(doc);
                  return _IncidentRow(incident: i, docId: doc.id, peranan: peranan);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  final IncidentModel incident;
  final String docId;
  final String peranan;
  const _IncidentRow({required this.incident, required this.docId, required this.peranan});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(incident.status);
    final catColor    = _catColor(incident.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: catColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(_catIcon(incident.category), color: catColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              incident.description.isNotEmpty ? incident.description : incident.category,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: kText1),
            ),
            const SizedBox(height: 2),
            Row(children: [
              Text(
                '${incident.userId.isNotEmpty ? incident.userId : '-'}  ·  ${DateFormat('dd/MM HH:mm').format(incident.timestamp)}',
                style: GoogleFonts.inter(fontSize: 11, color: kText3),
              ),
              if (incident.locationName.isNotEmpty) ...[
                const SizedBox(width: 6),
                const Icon(Icons.location_on, size: 11, color: kText3),
                Flexible(child: Text(
                  incident.locationName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: kText3),
                )),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        // Google Maps link
        if (incident.mapsUrl.isNotEmpty)
          InkWell(
            onTap: () => html.window.open(incident.mapsUrl, '_blank'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: kPrimaryLt, borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on, color: kPrimary, size: 12),
                const SizedBox(width: 3),
                Text('Maps', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: kPrimary)),
              ]),
            ),
          ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(IncidentModel.statusLabel(incident.status),
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor, letterSpacing: 0.3)),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => IncidentsScreen.showStatusDialog(context, docId, incident.status, peranan),
          style: OutlinedButton.styleFrom(
            foregroundColor: kPrimary, side: const BorderSide(color: kPrimary),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('Kemaskini', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'resolved':   return kSuccess;
      case 'responding': return kWarning;
      case 'received':   return kInfo;
      default:           return kDanger;
    }
  }

  Color _catColor(String c) {
    switch (c.toUpperCase()) {
      case 'SOS':     return kDanger;
      case 'MEDICAL': return kInfo;
      case 'FIRE':    return kWarning;
      default:        return kPrimary;
    }
  }

  IconData _catIcon(String c) {
    switch (c.toUpperCase()) {
      case 'SOS':     return Icons.sos;
      case 'MEDICAL': return Icons.medical_services_outlined;
      case 'FIRE':    return Icons.local_fire_department_outlined;
      default:        return Icons.report_outlined;
    }
  }
}

// ── SOS alerts card ────────────────────────────────────────────────────────────
class _SosAlerts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), boxShadow: kCardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.sos, color: kDanger, size: 20),
            const SizedBox(width: 8),
            Text('Isyarat SOS', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: kText1)),
          ]),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(IncidentModel.collection)
                .where('jenisInsiden', isEqualTo: 'SOS')
                .orderBy('tarikhMasa', descending: true)
                .limit(6)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: kPrimary)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Column(children: [
                    const Icon(Icons.check_circle_outline, color: kSuccess, size: 36),
                    const SizedBox(height: 8),
                    Text('Tiada SOS aktif', style: GoogleFonts.inter(fontSize: 13, color: kText3)),
                  ])),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final i = IncidentModel.fromFirestore(doc);
                  final resolved = i.status == 'resolved';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: resolved ? kBg : kDanger.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: resolved ? kBorder : kDanger.withValues(alpha: 0.25)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: resolved ? kSuccess.withValues(alpha: 0.1) : kDanger.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            resolved ? Icons.check_circle_outline : Icons.person_pin_circle_outlined,
                            color: resolved ? kSuccess : kDanger, size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.userId.isEmpty ? 'Tidak Diketahui' : i.userId,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: resolved ? kText2 : kText1)),
                          Text(DateFormat('dd/MM HH:mm').format(i.timestamp),
                              style: GoogleFonts.inter(fontSize: 10, color: kText3)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: resolved ? kSuccess.withValues(alpha: 0.1) : kWarning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(IncidentModel.statusLabel(i.status),
                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: resolved ? kSuccess : kWarning)),
                        ),
                      ]),
                      // Location + Maps link
                      if (i.locationName.isNotEmpty || i.mapsUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.location_on, size: 12, color: kDanger),
                          const SizedBox(width: 4),
                          Expanded(child: Text(
                            i.locationName.isNotEmpty ? i.locationName : i.koordinat,
                            style: GoogleFonts.inter(fontSize: 10, color: kText2),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          )),
                          if (i.mapsUrl.isNotEmpty)
                            InkWell(
                              onTap: () => html.window.open(i.mapsUrl, '_blank'),
                              child: Text('📍 Buka Maps',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: kPrimary,
                                      decoration: TextDecoration.underline)),
                            ),
                        ]),
                      ],
                    ]),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
