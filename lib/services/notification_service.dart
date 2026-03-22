import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:developer' as developer;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Initialize Timezone
    tz.initializeTimeZones();

    // 2. Android Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS Settings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 4. Windows Settings
    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
      appName: 'Pharmacy POS',
      appUserModelId: 'com.mhshadin.pharmacy_pos',
      guid: 'E4B0A9B3-E93D-4B0A-9B3E-4F3D6E7C8B9A',
    );

    // 5. Combine Settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      windows: initializationSettingsWindows,
    );

    // 6. Initialize Plugin
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        developer.log('Notification tapped: ${response.payload}');
      },
    );

    // 6. Request permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'general_alerts',
    String channelName = 'General Alerts',
    Importance importance = Importance.max,
    Priority priority = Priority.high,
    bool playSound = true,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
      showWhen: true,
      playSound: playSound,
      styleInformation: BigTextStyleInformation(body),
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  Future<void> showLowStockAlert(String productName, int stock) async {
    await showNotification(
      id: productName.hashCode,
      title: 'Low Stock Alert ⚠️',
      body: '$productName is low in stock ($stock remaining). Please restock soon.',
      channelId: 'stock_alerts',
      channelName: 'Stock Alerts',
    );
  }

  Future<void> showExpiryAlert(String productName, String expiryDate) async {
    await showNotification(
      id: productName.hashCode + 1,
      title: 'Expiry Warning ⌛',
      body: '$productName is expiring on $expiryDate. Check your inventory.',
      channelId: 'expiry_alerts',
      channelName: 'Expiry Alerts',
    );
  }
}
