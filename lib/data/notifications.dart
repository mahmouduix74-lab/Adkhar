import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer.dart';

/// Local prayer-time reminders. Entirely on-device: the schedule is already
/// computed offline, and these just hand the six times to the OS to fire
/// even with no network and the app closed. Nothing is sent anywhere.
class PrayerNotifications {
  PrayerNotifications._();
  static final instance = PrayerNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'prayer_times';
  static const _channelName = 'مواقيت الصلاة';

  Future<void> _ensureReady() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC rather than throwing — a reminder an hour off is
      // still better than the toggle failing outright.
    }
    await _plugin.initialize(
        settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    _ready = true;
  }

  /// Asks for permission and returns whether it was granted. Called the
  /// moment the user turns the toggle on.
  Future<bool> requestPermission() async {
    await _ensureReady();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      await android.requestExactAlarmsPermission();
      return granted;
    }
    return true;
  }

  /// Replaces every scheduled reminder with one per prayer in [schedule],
  /// each at the next occurrence of that time.
  Future<void> reschedule(List<Prayer> schedule) async {
    await _ensureReady();
    await cancelAll();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < schedule.length; i++) {
      final p = schedule[i];
      var when = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, p.minutes ~/ 60, p.minutes % 60);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

      await _plugin.zonedSchedule(
        id: i,
        title: 'حان وقت ${p.name}',
        body: 'صلاة ${p.name} — ${p.time}',
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      );
    }
    if (kDebugMode) {
      debugPrint('scheduled ${schedule.length} prayer reminders');
    }
  }

  Future<void> cancelAll() async {
    await _ensureReady();
    await _plugin.cancelAll();
  }
}
