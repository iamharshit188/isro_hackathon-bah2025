import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

// Note: This needs a running Firebase app to work.
// You must complete the Firebase setup for both Android and iOS platforms.

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Requesting permission for iOS and web
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('Permission granted: ${settings.authorizationStatus}');
    }

    // You can handle incoming messages here if needed
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) { ... });
  }

  Future<String?> getFcmToken() async {
    // You may need to provide your VAPID key for web.
    return await _fcm.getToken();
  }

  void subscribeToTopic(String topic) {
    _fcm.subscribeToTopic(topic);
  }
} 