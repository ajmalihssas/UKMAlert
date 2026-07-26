import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _idController = TextEditingController();
  final _emelController = TextEditingController();
  final _kataLaluanController = TextEditingController();
  final _sahKataLaluanController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String _peranan = 'pelajar';

  final List<Map<String, String>> _perananOptions = [
    {'value': 'pelajar', 'label': 'Pelajar'},
    {'value': 'kakitangan', 'label': 'Kakitangan'},
    {'value': 'pegawai_keselamatan', 'label': 'Pegawai Keselamatan'},
    {'value': 'admin', 'label': 'Admin'},
  ];

  @override
  void dispose() {
    _namaController.dispose();
    _idController.dispose();
    _emelController.dispose();
    _kataLaluanController.dispose();
    _sahKataLaluanController.dispose();
    super.dispose();
  }

  Future<void> _daftar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final nama = _namaController.text.trim();
    final idPengguna = _idController.text.trim();
    final emel = _emelController.text.trim();
    final kataLaluan = _kataLaluanController.text;

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emel,
        password: kataLaluan,
      );

      final user = credential.user;
      if (user == null) throw Exception('User is null after registration');

      // Update display name
      await user.updateDisplayName(nama);

      // Save to Firestore users collection
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'nama': nama,
        'idPengguna': idPengguna,
        'emel': emel,
        'peranan': _peranan,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pendaftaran berjaya! Selamat datang, $nama.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );

      // Navigate based on role
      switch (_peranan) {
        case 'pegawai_keselamatan':
          Navigator.pushNamedAndRemoveUntil(context, '/security_home', (_) => false);
          break;
        case 'admin':
          Navigator.pushNamedAndRemoveUntil(context, '/security_management', (_) => false);
          break;
        default:
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(_authErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Ralat sistem: ${e.toString()}');
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();

    if (code == 'email-already-in-use') {
      return 'Emel ini telah didaftarkan. Sila gunakan emel lain atau log masuk.';
    }
    if (code == 'invalid-email') {
      return 'Format emel tidak sah. Sila masukkan emel yang betul.';
    }
    if (code == 'weak-password' || msg.contains('weak')) {
      return 'Kata laluan terlalu lemah. Gunakan sekurang-kurangnya 6 aksara.';
    }
    if (code == 'operation-not-allowed' || msg.contains('not allowed') || msg.contains('not enabled')) {
      return 'Pendaftaran tidak dibenarkan. Sila aktifkan Email/Password di Firebase Console → Authentication → Sign-in method.';
    }
    if (code == 'network-request-failed' || msg.contains('network')) {
      return 'Tiada sambungan internet. Sila semak rangkaian anda.';
    }
    if (code == 'too-many-requests') {
      return 'Terlalu banyak percubaan. Sila tunggu sebentar.';
    }
    // Show real code so we can debug unknown errors
    return 'Ralat pendaftaran [${e.code}]: ${e.message ?? 'tiada mesej'}';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Daftar Akaun',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Header
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFF9E0000).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF9E0000), width: 2),
                          ),
                          child: const Icon(Icons.person_add, color: Color(0xFF9E0000), size: 36),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Cipta akaun UKMAlert anda',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Form card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('MAKLUMAT PERIBADI'),
                              const SizedBox(height: 12),

                              // Nama Penuh
                              _buildFormField(
                                controller: _namaController,
                                label: 'Nama Penuh',
                                hint: 'Masukkan nama penuh anda',
                                icon: Icons.person_outline,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Sila masukkan nama penuh';
                                  if (v.trim().length < 3) return 'Nama terlalu pendek';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // No. Matrik / ID
                              _buildFormField(
                                controller: _idController,
                                label: 'No. Matrik / ID Staf',
                                hint: 'cth: A204021 atau S12345',
                                icon: Icons.badge_outlined,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Sila masukkan No. Matrik/ID';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Email UKM
                              _buildFormField(
                                controller: _emelController,
                                label: 'Emel UKM',
                                hint: 'cth: A204021@siswa.ukm.edu.my',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Sila masukkan emel';
                                  if (!v.contains('@')) return 'Format emel tidak sah';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              _sectionLabel('PERANAN'),
                              const SizedBox(height: 12),

                              // Peranan dropdown
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _peranan,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF16213E),
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                    iconEnabledColor: Colors.white.withValues(alpha: 0.6),
                                    items: _perananOptions.map((opt) {
                                      return DropdownMenuItem<String>(
                                        value: opt['value'],
                                        child: Text(opt['label']!),
                                      );
                                    }).toList(),
                                    onChanged: (v) => setState(() => _peranan = v!),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              _sectionLabel('KATA LALUAN'),
                              const SizedBox(height: 12),

                              // Kata Laluan
                              _buildPasswordField(
                                controller: _kataLaluanController,
                                label: 'Kata Laluan',
                                obscure: _obscurePassword,
                                onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Sila masukkan kata laluan';
                                  if (v.length < 6) return 'Kata laluan sekurang-kurangnya 6 aksara';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Sahkan Kata Laluan
                              _buildPasswordField(
                                controller: _sahKataLaluanController,
                                label: 'Sahkan Kata Laluan',
                                obscure: _obscureConfirm,
                                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Sila sahkan kata laluan';
                                  if (v != _kataLaluanController.text) return 'Kata laluan tidak sepadan';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // Daftar button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _daftar,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF9E0000),
                                    disabledBackgroundColor: const Color(0xFF9E0000).withValues(alpha: 0.5),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : Text(
                                          'Daftar Sekarang',
                                          style: GoogleFonts.manrope(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Sudah ada akaun? ',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              child: Text(
                                'Log Masuk',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF9E0000),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.white.withValues(alpha: 0.4),
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(color: Colors.orangeAccent),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
        prefixIcon: Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.5)),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(color: Colors.orangeAccent),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}
