import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apps_packagebox/presentasion/pages/dashboard_section/home_page.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final String _apiBaseUrl = 'https://api-packagebox.vercel.app/api';
  static const String _fcmTokenKey = 'registeredFcmToken';

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    await NotificationService()._handleBackgroundMessage(message);
  }

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _requestNotificationPermissions();

      String? token = await _firebaseMessaging.getToken();
      print('Initial FCM Token: $token');

      await _configureLocalNotifications();
      _setupFirebaseMessaging();
      await _handleInitialNotification();

      // Cek box baru dan tampilkan notifikasi lokal
      await checkNewBoxesAndNotify();
    } catch (e) {
      print('Error initializing Firebase: $e');
      throw Exception('Failed to initialize Firebase: $e');
    }
  }

  Future<void> _requestNotificationPermissions() async {
    try {
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
        announcement: true,
        carPlay: true,
      );

      print('User granted permission: ${settings.authorizationStatus}');

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestPermission();
    } catch (e) {
      print('Error requesting permissions: $e');
      throw Exception('Failed to request permissions: $e');
    }
  }

  Future<void> _configureLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
      },
    );
  }

  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.notification?.title}');
      final type = message.data['type'];
      if (type == 'masuk') {
        _showLocalNotification(
          message.notification?.title ?? 'Notifikasi Paket Masuk',
          message.notification?.body ?? 'Silakan ambil paket Anda',
          payload: json.encode(message.data),
        );
      } else if (type == 'getar') {
        _showLocalNotification(
          message.notification?.title ?? 'Notifikasi Box Dibobol',
          message.notification?.body ?? 'Box Anda Dibobol! Silakan cek segera',
          payload: json.encode(message.data),
        );
      } else if (message.notification != null) {
        _showLocalNotification(
          message.notification?.title ?? 'SmartBox Update',
          message.notification?.body ?? 'New content available',
          payload: json.encode(message.data),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background via notification');
      _handleNotification(message);
    });
  }

  Future<void> _handleInitialNotification() async {
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('App opened from terminated state via notification');
      _handleNotification(initialMessage);
    }
  }

  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
    await _configureLocalNotifications();

    if (message.notification != null) {
      await _showLocalNotification(
        message.notification?.title ?? 'SmartBox Update',
        message.notification?.body ?? 'New content available',
        payload: json.encode(message.data),
      );
    }
  }

  void _handleNotification(RemoteMessage message) {
    print('Notification data: ${message.data}');
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  /// Cek box baru dari API dan tampilkan notifikasi lokal jika ada box baru
  List<String> _notifiedBoxIds = [];
  Future<void> checkNewBoxesAndNotify() async {
    try {
      final response = await http.get(
        Uri.parse('https://api-packagebox.vercel.app/api/boxes'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true && data['boxes'] is List) {
          for (final box in data['boxes']) {
            final id = box['id']?.toString() ?? '';
            if (!_notifiedBoxIds.contains(id)) {
              final type = box['type']?.toString() ?? '';
              final name =
                  box['name']?.toString() ?? box['boxId']?.toString() ?? '';
              if (type == 'masuk') {
                await _showLocalNotification(
                  'Notifikasi Paket Masuk',
                  'Silakan ambil paket Anda',
                  payload: json.encode(box),
                );
              } else if (type == 'getar') {
                await _showLocalNotification(
                  'Notifikasi Box Dibobol',
                  'Box Anda Dibobol! Silakan cek segera',
                  payload: json.encode(box),
                );
              }
              _notifiedBoxIds.add(id);
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching boxes for notification: $e');
    }
  }

  Future<bool> registerDeviceToken() async {
    try {
      if (!Firebase.apps.isNotEmpty) {
        await Firebase.initializeApp();
      }

      String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');

      if (token == null) {
        throw Exception('Failed to get FCM token');
      }

      final prefs = await SharedPreferences.getInstance();
      final registeredToken = prefs.getString(_fcmTokenKey);

      if (registeredToken != token) {
        final response = await http
            .post(
              Uri.parse('$_apiBaseUrl/fcm-tokens/register'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: json.encode({'token': token, 'skipTest': false}),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 201) {
          await prefs.setString(_fcmTokenKey, token);
          print('Token registered successfully');
          return true;
        } else {
          throw Exception('Failed to register token: ${response.statusCode}');
        }
      }

      return true;
    } catch (e) {
      print('Error in registerDeviceToken: $e');
      throw Exception('Failed to register device token: $e');
    }
  }

  Future<void> _showLocalNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'packagebox_channel',
      'PackageBox Updates',
      channelDescription: 'Channel for PackageBox notifications',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      vibrationPattern: Int64List.fromList([1000, 1000, 1000, 1000]),
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // Contoh fungsi fetch data lain (jika ingin meniru fetchNews/fetchKegiatan)
  Future<List<Map<String, dynamic>>> fetchBoxes() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/boxes'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['success'] == true && data['boxes'] is List) {
          return List<Map<String, dynamic>>.from(data['boxes']);
        } else {
          throw Exception(data['message'] ?? 'Unknown error');
        }
      } else {
        throw Exception('Failed to load boxes');
      }
    } catch (e) {
      print('Error fetching boxes: $e');
      throw Exception('Failed to load boxes');
    }
  }
}
