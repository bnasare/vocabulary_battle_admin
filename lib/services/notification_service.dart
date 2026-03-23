import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handle background messages (when app is terminated/background)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are automatically shown by FCM on Android/iOS
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request permission for iOS
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Setup background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    _setupForegroundMessageHandler();

    // Handle notification taps
    _setupNotificationTapHandler();

    _isInitialized = true;
  }

  /// Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // User granted notification permission
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      // User granted provisional permission
    } else {
      // User declined or has not accepted permission
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    // Android settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Setup foreground message handler (when app is open)
  void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Show notification even when app is in foreground
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });
  }

  /// Setup notification tap handler
  void _setupNotificationTapHandler() {
    // Handle notification tap when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    // Check if app was opened from a terminated state via notification
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationTap(message.data);
      }
    });
  }

  /// Show local notification (for foreground messages)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Android notification details
    const androidDetails = AndroidNotificationDetails(
      'vocab_battle_channel', // channel id
      'Vocabulary Battle', // channel name
      channelDescription: 'Notifications for Vocabulary Battle game',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode, // notification id
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    // ignore: unused_local_variable
    final sessionId = data['sessionId'] as String?;

    // TODO: Navigate to appropriate screen based on notification type
    // You can implement navigation logic here based on your requirements

    switch (type) {
      case 'opponentSubmitted':
        // Navigate to home screen - opponent submitted
        break;
      case 'battleReady':
        // Navigate to home screen - battle ready
        break;
      case 'deadlineReminder':
        // Navigate to question creation screen
        break;
      case 'deadlineMissed':
        // Navigate to home screen - deadline missed
        break;
      case 'battleDayReminder':
        // Navigate to home screen - battle day
        break;
      case 'gameComplete':
        // Navigate to results screen
        break;
      default:
        // Unknown notification type
        break;
    }

    // Example: If you want to navigate, you can use a GlobalKey<NavigatorState>
    // navigatorKey.currentState?.pushNamed('/home', arguments: sessionId);
  }

  /// Local notification tap handler
  void _onNotificationTapped(NotificationResponse response) {
    // Handle local notification tap
  }

  /// Get FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
