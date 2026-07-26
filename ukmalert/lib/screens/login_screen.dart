import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';
import 'adhoc_screen.dart';

const _kDefaultEmailDomain = 'siswa.ukm.edu.my';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<String> _resolveEmail(String username) async {
    if (username.contains('@')) return username;
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('idPengguna', isEqualTo: username)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final email = (query.docs.first.data()['emel'] ?? '').toString();
        if (email.isNotEmpty) return email;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_resolveEmail error: $e');
    }
    return '$username@$_kDefaultEmailDomain';
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final username = _usernameController.text.trim();
    final password = _passwordController.text; // no trim — passwords may have leading/trailing spaces
    setState(() { _isLoading = true; _error = ''; });
    try {
      final email = await _resolveEmail(username);
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        setState(() => _error = 'Log masuk gagal. Sila cuba lagi.');
        return;
      }
      // Fetch role and update lastLogin in parallel to avoid a sequential round-trip
      final docFuture = FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'lastLogin': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      final doc = await docFuture;
      if (!mounted) return;
      await _navigateByRole(doc);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _firebaseErrorMessage(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Ralat sambungan. Sila semak internet anda.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateByRole(DocumentSnapshot doc) async {
    if (!mounted) return;
    String peranan = 'pelajar';
    if (doc.exists) {
      try {
        peranan = ((doc.data() as Map<String, dynamic>)['peranan'] ?? 'pelajar')
            .toString()
            .toLowerCase();
      } catch (_) {}
    }
    switch (peranan) {
      case 'pegawai_keselamatan':
        Navigator.pushReplacementNamed(context, '/security_home');
        break;
      case 'admin':
        Navigator.pushReplacementNamed(context, '/security_management');
        break;
      default:
        Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _loginAsGuest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log Masuk sebagai Tetamu',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Anda akan log masuk tanpa akaun. Data dan laporan tidak akan disimpan.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Teruskan',
              style: GoogleFonts.inter(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { _isLoading = true; _error = ''; });
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _firebaseErrorMessage(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Ralat sambungan. Sila cuba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Masukkan No. Matrik/ID atau emel untuk set semula kata laluan.');
      return;
    }
    setState(() { _isLoading = true; _error = ''; });
    try {
      final email = await _resolveEmail(username);
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pautan set semula dihantar ke $email',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _firebaseErrorMessage(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Ralat sistem. Sila cuba lagi kemudian.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    if (code == 'wrong-password' || code == 'invalid-credential' ||
        code == 'invalid_login_credentials' || msg.contains('invalid_login_credentials') ||
        msg.contains('wrong password')) {
      return 'No. Matrik/ID atau kata laluan tidak tepat.';
    }
    if (code == 'user-not-found' || msg.contains('no user record')) {
      return 'Akaun tidak ditemui. Sila daftar terlebih dahulu.';
    }
    if (code == 'user-disabled') return 'Akaun anda telah dinyahaktifkan.';
    if (code == 'too-many-requests' || msg.contains('too many')) {
      return 'Terlalu banyak percubaan. Sila tunggu sebentar.';
    }
    if (code == 'network-request-failed') return 'Tiada sambungan internet.';
    return 'Log masuk gagal. Sila cuba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _UkmCrest(size: 72),
                  const SizedBox(height: 16),
                  Text(
                    'Universiti Kebangsaan Malaysia',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'UKMAlert',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Log masuk untuk meneruskan',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 36),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('NO. MATRIK / ID / EMEL'),
                        const SizedBox(height: 6),
                        _inputField(
                          controller: _usernameController,
                          hint: 'cth: A204021 atau staf@ukm.edu.my',
                          icon: Icons.badge_outlined,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Sila masukkan No. Matrik/ID atau emel.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('KATA LALUAN'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _isLoading ? null : _login(),
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Sila masukkan kata laluan.'
                              : null,
                          decoration: _deco('••••••••', Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Tunjuk kata laluan'
                                  : 'Sembunyi kata laluan',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.onSurfaceVariant,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: const Size(48, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Lupa kata laluan?',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                        // Firebase error banner
                        if (_error.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: AppColors.error, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error,
                                      style: GoogleFonts.inter(
                                          fontSize: 12, color: AppColors.error)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Log Masuk button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.primary.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : Text(
                                    'Log Masuk',
                                    style: GoogleFonts.inter(
                                        fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Daftar
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const RegisterScreen())),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.onSurface,
                              side: BorderSide(
                                  color: AppColors.outlineVariant, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Daftar Akaun Baru',
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: AppColors.outlineVariant, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'ATAU',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Divider(
                              color: AppColors.outlineVariant, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tetamu
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : _loginAsGuest,
                      icon: Icon(Icons.person_outline,
                          color: AppColors.onSurfaceVariant, size: 18),
                      label: Text(
                        'Teruskan sebagai Tetamu',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  // Offline Ad Hoc mode — Android only
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: AppColors.outlineVariant, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'KECEMASAN TANPA INTERNET',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: AppColors.tertiary,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: AppColors.outlineVariant, thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdhocScreen()),
                        ),
                        icon: const Icon(Icons.wifi_tethering,
                            size: 18, color: AppColors.tertiary),
                        label: Text(
                          'Mod Luar Talian — Rangkaian Ad Hoc',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tertiary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.tertiary, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hantar mesej kecemasan tanpa log masuk atau internet\nmelalui Bluetooth & Wi-Fi Direct berdekatan.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurfaceVariant,
          letterSpacing: 1.5,
        ),
      );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputAction textInputAction = TextInputAction.done,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
        decoration: _deco(hint, icon),
      );

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error, width: 1.5)),
      );
}

// ── UKM Crest ─────────────────────────────────────────────────────────────────
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
        border: Border.all(color: AppColors.primary, width: size * 0.04),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'UKM',
            style: GoogleFonts.inter(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: size * 0.45,
            height: size * 0.055,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}
