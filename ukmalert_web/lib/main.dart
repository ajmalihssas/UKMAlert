import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/admin_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ms', null);
  Object? initError;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    initError = e;
  }
  runApp(UKMAlertAdminApp(initError: initError));
}

class UKMAlertAdminApp extends StatelessWidget {
  final Object? initError;
  const UKMAlertAdminApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UKMAlert Admin',
      debugShowCheckedModeBanner: false,
      theme: webTheme(),
      home: initError != null
          ? _FirebaseErrorScaffold(error: initError.toString())
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _FirebaseErrorScaffold(
                      error: snapshot.error.toString());
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: kBg,
                    body: Center(
                      child: CircularProgressIndicator(color: kPrimary),
                    ),
                  );
                }
                if (snapshot.hasData) {
                  return _RoleGate(uid: snapshot.data!.uid);
                }
                return const LoginScreen();
              },
            ),
    );
  }
}

// ── Firebase init error scaffold ──────────────────────────────────────────────
class _FirebaseErrorScaffold extends StatelessWidget {
  final String error;
  const _FirebaseErrorScaffold({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: kCardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: kDanger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.cloud_off, color: kDanger, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'Ralat Sambungan Firebase',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: kText1),
              ),
              const SizedBox(height: 8),
              Text(
                'Sistem tidak dapat disambungkan ke pelayan. '
                'Semak sambungan internet dan cuba muat semula.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: kText2),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kDanger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kDanger.withValues(alpha: 0.2)),
                ),
                child: Text(
                  error,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: kDanger),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Role gate ─────────────────────────────────────────────────────────────────
class _RoleGate extends StatelessWidget {
  final String uid;
  const _RoleGate({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: CircularProgressIndicator(color: kPrimary),
            ),
          );
        }

        if (snapshot.hasError) {
          final err = snapshot.error.toString();
          return _FirebaseErrorScaffold(error: err);
        }



        final docData = snapshot.data?.data() as Map<String, dynamic>?;
        final peranan = docData?['peranan']?.toString().toLowerCase() ?? '';

        if (peranan == 'pegawai_keselamatan' || peranan == 'admin') {
          return AdminShell(peranan: peranan);
        }
        return _AccessDeniedScaffold();
      },
    );
  }
}

// ── Access denied scaffold ────────────────────────────────────────────────────
class _AccessDeniedScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: kCardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: kDanger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    color: kDanger, size: 32),
              ),
              const SizedBox(height: 20),
              Text('Akses Ditolak',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: kText1)),
              const SizedBox(height: 8),
              Text(
                'Hanya pegawai keselamatan dan admin dibenarkan '
                'mengakses sistem ini.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: kText2),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: kSurface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Log Keluar',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
