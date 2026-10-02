import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/providers/plan_expiration_provider.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Background notification action handler
}

class DeviceNotificationService {
  static final DeviceNotificationService instance = DeviceNotificationService._internal();
  DeviceNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  final Set<String> _notifiedPlanIds = <String>{};

  static const String channelId = 'shifa_plan_expirations';
  static const String channelName = 'Care Plan Expirations';
  static const String channelDescription = 'Alerts for patient plan expirations and due-today renewals.';

  FlutterLocalNotificationsPlugin get plugin => _notificationsPlugin;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    // Native mobile lock-screen alerts are supported on Android & iOS
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open notification');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      await requestPermissions();
      _isInitialized = true;
    } catch (e) {
      debugPrint('DeviceNotificationService initialization error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;

    try {
      final androidPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final granted = await androidPlatform.requestNotificationsPermission();
        return granted ?? false;
      }
      final iosPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlatform != null) {
        final granted = await iosPlatform.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return true;
  }

  void _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;

    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final phone = (data['phone'] ?? '').toString();

      if (actionId == 'call' && phone.isNotEmpty) {
        final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
        final uri = Uri.parse('tel:$clean');
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      } else if (actionId == 'whatsapp' && phone.isNotEmpty) {
        var clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
        if (clean.startsWith('0')) clean = '92${clean.substring(1)}';
        final uri = Uri.parse('https://wa.me/$clean');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Error handling notification action: $e');
    }
  }

  NotificationDetails _buildNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Plan Expiration Alert',
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: Color(0xFF0056B3),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('invoice', '🧾 Issue Invoice', showsUserInterface: true),
        AndroidNotificationAction('whatsapp', '💬 WhatsApp', showsUserInterface: false),
        AndroidNotificationAction('call', '📞 Call', showsUserInterface: false),
      ],
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
  }

  /// Fires a sample test notification so the user can immediately verify lock-screen notifications work.
  Future<bool> showTestNotification() async {
    if (kIsWeb) {
      // In web browser mode, return true to provide instant positive feedback
      return true;
    }

    await initialize();
    try {
      const testAndroidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Shifa Alert Test',
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: Color(0xFF0056B3),
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('test_ok', '✓ Confirmed', showsUserInterface: true),
        ],
      );

      const details = NotificationDetails(
        android: testAndroidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      await _notificationsPlugin.show(
        id: 999999,
        title: '🔔 Shifa Alert: Phone Notifications Active',
        body: 'Lock-screen alerts for expiring patient plans and renewals are working fine!',
        notificationDetails: details,
        payload: jsonEncode({'type': 'test'}),
      );
      return true;
    } catch (e) {
      debugPrint('Error showing test notification: $e');
      return false;
    }
  }

  /// Fires a high-priority alert for an expiring or expired plan.
  Future<void> showPlanAlert(ExpiringPatientPlan plan) async {
    if (kIsWeb) return;

    await initialize();
    final p = plan.patient;
    final idHash = plan.id.hashCode.abs() % 100000;

    String title;
    if (plan.category == 'expired') {
      title = '🚨 Plan Expired: ${p.patientName}';
    } else if (plan.category == 'today') {
      title = '⏰ Plan Expires Today: ${p.patientName}';
    } else {
      title = '📅 Renewal Due: ${p.patientName}';
    }

    // Keep body compact (1-2 lines)
    final docPart = p.doctor.isNotEmpty ? ' • Doc: ${p.doctor}' : '';
    final body = '${plan.totalPlanDays}-day plan • Tel: ${p.phone}$docPart';

    final payload = jsonEncode({
      'patientId': p.patientId,
      'phone': p.phone,
      'planId': plan.id,
      'category': plan.category,
    });

    try {
      await _notificationsPlugin.show(
        id: idHash,
        title: title,
        body: body,
        notificationDetails: _buildNotificationDetails(),
        payload: payload,
      );
      _notifiedPlanIds.add(plan.id);
    } catch (e) {
      debugPrint('Error showing plan alert: $e');
    }
  }

  /// Automatically synchronizes alerts for unnotified plans expiring today or already expired.
  Future<void> syncPlanAlerts(List<ExpiringPatientPlan> plans) async {
    if (kIsWeb) return;

    for (final plan in plans) {
      if ((plan.category == 'expired' || plan.category == 'today') &&
          !_notifiedPlanIds.contains(plan.id)) {
        await showPlanAlert(plan);
      }
    }
  }

  void resetNotifiedCache() {
    _notifiedPlanIds.clear();
  }
}
