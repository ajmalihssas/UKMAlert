import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'admin_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String _error = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();
      final peranan =
          (doc.data()?['peranan'] ?? '').toString().toLowerCase();
      if (peranan != 'pegawai_keselamatan' && peranan != 'admin') {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error =
              'Akses ditolak. Hanya pegawai keselamatan dan admin dibenarkan.';
          _loading = false;
        });
        return;
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminShell(peranan: peranan)),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error   = _mapError(e.code);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error   = 'Log masuk gagal. Sila cuba lagi.';
        _loading = false;
      });
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mel atau kata laluan tidak sah.';
      case 'too-many-requests':
        return 'Terlalu banyak percubaan. Cuba lagi sebentar.';
      default:
        return 'Log masuk gagal. Sila cuba lagi.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Row(
        children: [
          // ── Left branding panel ───────────────────────────────────────────
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kPrimary, Color(0xFF6B0000)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 56, vertical: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // UKM crest badge
                    _UkmCrest(size: 72),
                    const SizedBox(height: 16),
                    Text(
                      'Universiti Kebangsaan Malaysia',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(
                          color: Color(0x33FFFFFF), thickness: 1),
                    ),
                    Text(
                      'UKMAlert',
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sistem Pengurusan Keselamatan Kampus',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 48),
                    _featureRow(
                      Icons.radar_outlined,
                      'Pemantauan Insiden Masa Nyata',
                    ),
                    const SizedBox(height: 20),
                    _featureRow(
                      Icons.sync_alt_outlined,
                      'Kemaskini Status Automatik',
                    ),
                    const SizedBox(height: 20),
                    _featureRow(
                      Icons.notifications_active_outlined,
                      'Notifikasi Segera kepada Pengguna',
                    ),
                    const Spacer(),
                    Text(
                      '© 2025 Universiti Kebangsaan Malaysia',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Right login panel ─────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Container(
              color: kSurface,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _UkmCrest(size: 56),
                        const SizedBox(height: 24),
                        Text(
                          'Selamat Datang',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: kText1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Log masuk untuk mengakses sistem kawalan',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: kText2),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Email field
                        _fieldLabel('E-MEL'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          onSubmitted: (_) => _login(),
                          style: GoogleFonts.inter(
                              fontSize: 14, color: kText1),
                          decoration: _inputDeco(
                              'contoh@ukm.edu.my',
                              Icons.email_outlined),
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        _fieldLabel('KATA LALUAN'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          onSubmitted: (_) => _login(),
                          style: GoogleFonts.inter(
                              fontSize: 14, color: kText1),
                          decoration: _inputDeco(
                            '••••••••',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: kText3,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),

                        // Error banner
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: kDanger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: kDanger.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: kDanger, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error,
                                      style: GoogleFonts.inter(
                                          fontSize: 13, color: kDanger)),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              foregroundColor: kSurface,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5))
                                : Text(
                                    'Log Masuk',
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Text(
                          'Akses terhad kepada pegawai bertauliah sahaja',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: kText3),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: GoogleFonts.inter(
              fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kText3,
            letterSpacing: 1.5,
          ),
        ),
      );

  InputDecoration _inputDeco(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: kText3, fontSize: 14),
        prefixIcon: Icon(icon, color: kText3, size: 20),
        filled: true,
        fillColor: kBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

// ── UKM Crest widget (reusable) ───────────────────────────────────────────────
class _UkmCrest extends StatelessWidget {
  final double size;
  const _UkmCrest({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
            color: const Color(0xFF003087), width: size * 0.04),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'UKM',
            style: GoogleFonts.inter(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF003087),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: size * 0.45,
            height: size * 0.055,
            color: const Color(0xFFFDB913),
          ),
        ],
      ),
    );
  }
}
