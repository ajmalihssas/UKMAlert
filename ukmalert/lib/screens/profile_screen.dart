import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../providers/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _roleLabel(String peranan) {
    switch (peranan) {
      case 'kakitangan': return 'KAKITANGAN';
      case 'pegawai_keselamatan': return 'PEGAWAI KESELAMATAN';
      case 'admin': return 'ADMIN';
      default: return 'PELAJAR';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload if user data not yet available (e.g. navigated here directly).
    final up = context.read<UserProvider>();
    if (up.currentUser == null && !up.isLoading) {
      up.loadUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha:0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Profil',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        child: Column(
          children: [
            // Profile avatar
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.tertiaryFixed, width: 4),
                      ),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        child: Icon(Icons.person, size: 56, color: AppColors.primary),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            userProvider.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  )
                : Text(
                    userProvider.nama.isNotEmpty
                        ? userProvider.nama
                        : (userProvider.emel.isNotEmpty
                            ? userProvider.emel.split('@').first
                            : 'Pengguna'),
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
            const SizedBox(height: 4),
            Text(
              userProvider.idPengguna.isNotEmpty
                  ? '${_roleLabel(userProvider.peranan)}  ·  ${userProvider.idPengguna.toUpperCase()}'
                  : _roleLabel(userProvider.peranan),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.email_outlined,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emel Berdaftar',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userProvider.emel.isNotEmpty
                              ? userProvider.emel
                              : '-',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Tetapan Akaun
            _buildSectionHeader('TETAPAN AKAUN'),
            const SizedBox(height: 12),
            _buildSettingsGroup([
              _buildSettingsItem(Icons.person_outline, 'Maklumat Peribadi', AppColors.secondary),
              _buildSettingsItem(Icons.lock_open, 'Tukar Kata Laluan', AppColors.secondary),
              _buildSettingsItem(Icons.admin_panel_settings, 'Tetapan Keselamatan', AppColors.secondary),
            ]),
            const SizedBox(height: 24),

            // Keutamaan
            _buildSectionHeader('KEUTAMAAN'),
            const SizedBox(height: 12),
            _buildSettingsGroup([
              _buildToggleItem(Icons.dark_mode, 'Mod Gelap', AppColors.tertiary, themeProvider),
              _buildSettingsItem(Icons.notifications_active, 'Tetapan Notifikasi', AppColors.tertiary),
              _buildLanguageItem(),
            ]),
            const SizedBox(height: 24),

            // Sokongan
            _buildSectionHeader('SOKONGAN & MAKLUMAT'),
            const SizedBox(height: 12),
            _buildSettingsGroup([
              _buildSettingsItem(Icons.help_center, 'Pusat Bantuan', AppColors.onSurfaceVariant),
              _buildSettingsItem(Icons.description, 'Terma Perkhidmatan', AppColors.onSurfaceVariant),
              _buildSettingsItem(Icons.info_outline, 'Tentang UKMAlert', AppColors.onSurfaceVariant),
            ]),
            const SizedBox(height: 28),

            // Log Keluar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: Text('Log Keluar',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 18)),
                      content: Text(
                        'Adakah anda pasti ingin log keluar?',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Batal',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceVariant)),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(
                                  context, '/login');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Log Keluar',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.logout, size: 18),
                label: Text(
                  'Log Keluar',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.08),
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'UKMALERT V2.4.0',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurfaceVariant,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem(IconData icon, String label, Color iconColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem(IconData icon, String label, Color iconColor,
      ThemeProvider themeProvider) {
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.onSurface),
            ),
          ),
          Switch(
            value: isDarkMode,
            onChanged: (v) => themeProvider.toggleTheme(v),
            activeThumbColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageItem() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.language, color: AppColors.tertiary, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bahasa',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: AppColors.onSurface),
                    ),
                    Text(
                      'Bahasa Malaysia / English',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 18),
            ],
          ),
        ),
      ),
    );
  }
}


