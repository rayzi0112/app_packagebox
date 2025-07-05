
import 'package:apps_packagebox/domain/notification_service.dart';
import 'package:apps_packagebox/notification_screen.dart';
import 'package:apps_packagebox/presentasion/pages/auth_section/auth_choice.dart';
import 'package:apps_packagebox/presentasion/pages/auth_section/signin_page.dart';
import 'package:apps_packagebox/presentasion/pages/auth_section/signup_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apps_packagebox/presentasion/pages/dashboard_section/home_page.dart';
Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(
      NotificationService.firebaseMessagingBackgroundHandler,
    );

    runApp(MyApp());
  } catch (e) {
    print('Error initializing app: $e');
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