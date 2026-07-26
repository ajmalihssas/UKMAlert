import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/sos_queue_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'providers/user_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/report_history_screen.dart';
import 'screens/security_home_screen.dart';
import 'screens/security_management_screen.dart';
import 'screens/register_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Handle background FCM messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore disk cache so writes survive brief connectivity drops
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Flush any SOS reports that were queued while offline
  SosQueueService().uploadPendingQueue().then((n) {
    if (n > 0) debugPrint('[Startup] Uploaded $n queued SOS report(s).');
  });

  if (!kIsWeb) {
    // FCM background handler — not supported on web
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Local notifications setup
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ukmalert_channel',
      'UKMAlert Notifications',
      description: 'Notifikasi kecemasan UKM',
      importance: Importance.max,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request FCM permission — fire-and-forget; don't block startup
    FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Subscribe to broadcast topic — fire-and-forget; FCM retries automatically
    FirebaseMessaging.instance
        .subscribeToTopic('ukmalert_broadcast')
        .catchError((e) => debugPrint('FCM subscribe error: $e'));

    // Listen to foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const UKMAlertApp(),
    ),
  );
}

class UKMAlertApp extends StatelessWidget {
  const UKMAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'UKMAlert',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.themeMode,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // Load user profile into provider when auth state is ready
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<UserProvider>().loadUser();
            });
            return const RoleBasedHome();
          }
          return const LoginScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const MainShell(),
        '/history': (context) => const ReportHistoryScreen(),
        '/security_home': (context) => const SecurityHomeScreen(),
        '/security_management': (context) => const SecurityManagementScreen(),
      },
    );
  }
}

/// Routes user to the correct screen based on their 'peranan' in Firestore
class RoleBasedHome extends StatelessWidget {
  const RoleBasedHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginScreen();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        String peranan = 'pelajar';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          peranan = (data['peranan'] ?? 'pelajar').toString().toLowerCase();
        }

        switch (peranan) {
          case 'pegawai_keselamatan':
            return const SecurityHomeScreen();
          case 'admin':
            return const SecurityManagementScreen();
          default:
            return const MainShell();
        }
      },
    );
  }
}
