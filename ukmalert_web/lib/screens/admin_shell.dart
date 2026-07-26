import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'incidents_screen.dart';
import 'send_notification_screen.dart';
import 'users_screen.dart';
import 'adhoc_logs_screen.dart';

class AdminShell extends StatefulWidget {
  final String peranan;
  const AdminShell({super.key, required this.peranan});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  List<_NavItem> get _navItems {
    final items = <_NavItem>[
      const _NavItem(Icons.grid_view_outlined,      'Papan Pemuka'),
      const _NavItem(Icons.assignment_outlined,      'Insiden'),
      const _NavItem(Icons.notifications_outlined,   'Notifikasi'),
      const _NavItem(Icons.wifi_tethering,           'Log Ad-Hoc'),
    ];
    if (widget.peranan == 'admin') {
      items.add(const _NavItem(Icons.people_outline, 'Pengguna'));
    }
    return items;
  }

  Widget get _currentScreen {
    switch (_selectedIndex) {
      case 0: return DashboardScreen(peranan: widget.peranan);
      case 1: return IncidentsScreen(peranan: widget.peranan);
      case 2: return const SendNotificationScreen();
      case 3: return const AdhocLogsScreen();
      case 4: return const UsersScreen();
      default: return DashboardScreen(peranan: widget.peranan);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Keluar',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: kText1)),
        content: Text('Adakah anda pasti ingin log keluar dari sistem?',
            style: GoogleFonts.inter(fontSize: 14, color: kText2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kText2)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: kSurface, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Log Keluar', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems;
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────────
          Container(
            width: 248,
            color: kSidebar,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand area
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('UKMAlert',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          Text(
                            widget.peranan == 'admin' ? 'Admin' : 'Pegawai Keselamatan',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // System active pill
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: kSuccess.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(color: kSuccess, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Text('Sistem Aktif',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: kSuccess)),
                    ]),
                  ),
                ),
                const SizedBox(height: 28),

                // Section label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('NAVIGASI',
                      style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.3), letterSpacing: 2)),
                ),
                const SizedBox(height: 8),

                // Nav items
                ...List.generate(navItems.length, (i) {
                  final item = navItems[i];
                  final isActive = _selectedIndex == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isActive ? kPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(item.icon,
                            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
                            size: 18),
                        const SizedBox(width: 12),
                        Text(item.label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
                            )),
                      ]),
                    ),
                  );
                }),

                const Spacer(),

                // User email
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(userEmail,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                ),

                // Logout button
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  child: GestureDetector(
                    onTap: _confirmLogout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.logout, color: Colors.white.withValues(alpha: 0.5), size: 18),
                        const SizedBox(width: 12),
                        Text('Log Keluar',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Main content area ────────────────────────────────────────────────
          Expanded(
            child: Container(
              color: kBg,
              child: _currentScreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
