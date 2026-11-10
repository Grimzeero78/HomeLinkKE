// HuntInKE — local notifications (flutter_local_notifications).
// Two channels, same idea as the website's badges:
//   · messages  — new chat messages (fires when the unread poll sees new mail)
//   · account   — boost / verification / listing events
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'theme.dart';

class Notifs {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _id = 100;

  static Future<void> init() async {
    if (_ready) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_huntin'),
    );
    await plugin.initialize(settings);
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'messages', 'Messages',
      description: 'New messages from landlords and renters',
      importance: Importance.max,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'account', 'Account & listings',
      description: 'Boost, verification and listing updates',
      importance: Importance.defaultImportance,
    ));
    _ready = true;
  }

  static NotificationDetails _details(String channel) {
    final green = channel == 'messages' ? const Color(0xFF0E5A33) : C.ember;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel, channel == 'messages' ? 'Messages' : 'Account & listings',
        channelDescription: channel == 'messages'
            ? 'New messages from landlords and renters'
            : 'Boost, verification and listing updates',
        importance: channel == 'messages' ? Importance.max : Importance.defaultImportance,
        priority: channel == 'messages' ? Priority.high : Priority.defaultPriority,
        color: green,
        styleInformation: const BigTextStyleInformation(''),
      ),
    );
  }

  static Future<void> showMessage(String title, String body) async {
    if (!_ready) return;
    try {
      await plugin.show(_id++, title, body, _details('messages'));
    } catch (_) {}
  }

  static Future<void> showAccount(String title, String body) async {
    if (!_ready) return;
    try {
      await plugin.show(_id++, title, body, _details('account'));
    } catch (_) {}
  }
}
