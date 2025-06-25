import 'package:apps_packagebox/screens/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'welcome_screen.dart';
import 'auth/auth_choice.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:apps_packagebox/services/notification_service.dart';
import 'auth/signin.dart';
import 'auth/signup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  try {
    // Ensure Flutter bindings are initialized
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase first
    await Firebase.initializeApp();

    
    // Only set up background message handler after Firebase is initialized
    FirebaseMessaging.onBackgroundMessage(
      NotificationService.firebaseMessagingBackgroundHandler,
    );

    runApp(MyApp());
  } catch (e) {
    print('Error initializing app: $e');
    // You might want to show an error screen here
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app: $e'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final NotificationService _notificationService = NotificationService();

  MyApp({super.key});

  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final isNotificationEnabled = prefs.getBool('isNotificationEnabled') ?? false;

    // Logika navigasi yang diperbaiki:
    // 1. Jika sudah login, langsung ke HomePage (tidak peduli status notifikasi)
    // 2. Jika belum login tapi notifikasi sudah pernah diatur, ke AuthChoiceScreen
    // 3. Jika belum login dan notifikasi belum pernah diatur, ke NotificationScreen
    
    if (isLoggedIn) {
      // Sudah login, langsung ke home
      return const HomePage();
    } else if (isNotificationEnabled || prefs.containsKey('isNotificationEnabled')) {
      // Belum login tapi notifikasi sudah pernah diatur (aktif/tidak aktif), ke auth choice
      return const AuthChoiceScreen();
    } else {
      // Belum login dan notifikasi belum pernah diatur, ke notification screen
      return const NotificationScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Box',
      debugShowCheckedModeBanner: false,
      navigatorKey: _notificationService.navigatorKey, // Add this line
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return snapshot.data!;
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
      routes: {
        '/auth-choice': (context) => const AuthChoiceScreen(),
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
      },
    );
  }
}