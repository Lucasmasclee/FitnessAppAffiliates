import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const String _keyTimerEndMs = 'rest_timer_end_ms';
const int _notificationId = 1;
/// Andere ID voor de directe "rust voorbij"-melding, zodat cancel() die niet meteen opheft.
const int _notificationIdExpired = 2;

/// Service voor de rusttijd-timer: gebaseerd op echte tijd, blijft correct na app-herstart.
class RestTimerService extends ChangeNotifier {
  RestTimerService._();
  static final RestTimerService instance = RestTimerService._();

  int? _endTimeMs;
  Timer? _ticker;
  bool _initialized = false;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Of de timer momenteel loopt (totdat gestopt of op 0).
  bool get isActive {
    if (_endTimeMs == null) return false;
    final remaining = (_endTimeMs! - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
    if (remaining <= 0) {
      _clearTimer(showExpiredNotification: true);
      return false;
    }
    return true;
  }

  /// Resterende seconden, of null als geen actieve timer.
  int? get remainingSeconds {
    if (_endTimeMs == null) return null;
    final remaining = (_endTimeMs! - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
    if (remaining <= 0) {
      _clearTimer(showExpiredNotification: true);
      return null;
    }
    return remaining;
  }

  /// Geformatteerde resterende tijd (MM:SS).
  String? get remainingFormatted {
    final s = remainingSeconds;
    if (s == null) return null;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// Initialiseer (prefs laden, notificaties, timezone). Roep eenmalig bij app-start.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final timeZoneName = timeZoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    final android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(
      InitializationSettings(android: android, iOS: ios),
    );
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'rest_timer_channel',
          'Rusttijd',
          description: 'Melding wanneer rusttijd voorbij is',
          importance: Importance.high,
        ),
      );
      await androidPlugin.requestNotificationsPermission();
    }
    await _loadFromPrefs();
    _initialized = true;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_keyTimerEndMs);
    if (stored != null && stored > DateTime.now().millisecondsSinceEpoch) {
      _endTimeMs = stored;
      try {
        await _scheduleNotification(stored);
      } catch (_) {}
      _startTicker();
      notifyListeners();
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_endTimeMs == null) {
      await prefs.remove(_keyTimerEndMs);
    } else {
      await prefs.setInt(_keyTimerEndMs, _endTimeMs!);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isActive) {
        _ticker?.cancel();
      }
      notifyListeners();
    });
  }

  void _clearTimer({bool showExpiredNotification = false}) {
    _endTimeMs = null;
    _ticker?.cancel();
    _notifications.cancel(_notificationId);
    _saveToPrefs();
    if (showExpiredNotification) {
      _showExpiredNotification();
    }
  }

  /// Toont direct een notificatie wanneer de rusttijd afloopt (fallback als geplande notificatie niet verscheen).
  /// Gebruikt _notificationIdExpired zodat cancel(_notificationId) deze melding niet opheft.
  Future<void> _showExpiredNotification() async {
    const android = AndroidNotificationDetails(
      'rest_timer_channel',
      'Rusttijd',
      channelDescription: 'Melding wanneer rusttijd voorbij is',
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    try {
      await _notifications.show(
        _notificationIdExpired,
        'Rusttijd',
        'Rusttijd is voorbij',
        details,
      );
    } catch (e) {
      debugPrint('Rest timer: show expired notification failed: $e');
    }
  }

  /// Start de rusttijd-timer voor [durationSeconds] seconden.
  /// Vraagt indien nodig notificatietoestemming aan (Android 13+).
  Future<void> start(int durationSeconds) async {
    if (durationSeconds <= 0) return;
    await ensureInitialized();
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
    _endTimeMs =
        DateTime.now().millisecondsSinceEpoch + (durationSeconds * 1000);
    await _saveToPrefs();
    await _scheduleNotification(_endTimeMs!);
    _startTicker();
    notifyListeners();
  }

  /// Schedules the "rest over" notification. Throws if scheduling fails.
  Future<void> _scheduleNotification(int endTimeMs) async {
    final scheduledDate = tz.TZDateTime.from(
      DateTime.fromMillisecondsSinceEpoch(endTimeMs),
      tz.local,
    );
    const android = AndroidNotificationDetails(
      'rest_timer_channel',
      'Rusttijd',
      channelDescription: 'Melding wanneer rusttijd voorbij is',
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    try {
      await _notifications.zonedSchedule(
        _notificationId,
        'Rusttijd',
        'rest time over',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, stack) {
      final isExactAlarmDenied = e.toString().contains('exact_alarms_not_permitted');
      if (isExactAlarmDenied) {
        try {
          await _notifications.zonedSchedule(
            _notificationId,
            'Rusttijd',
            'rest time over',
            scheduledDate,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e2, stack2) {
          debugPrint('Rest timer: scheduled notification failed: $e2');
          debugPrint(stack2.toString());
          rethrow;
        }
      } else {
        debugPrint('Rest timer: scheduled notification failed: $e');
        debugPrint(stack.toString());
        rethrow;
      }
    }
  }

  /// Stop de timer en verberg de widget.
  void stop() {
    _clearTimer();
    notifyListeners();
  }
}

/// Parsed een rusttijd-string (bijv. "90s", "2 min", "3") naar seconden.
/// Fallback 180 als leeg of ongeldig.
int parseRestTimeToSeconds(String restTime) {
  if (restTime.trim().isEmpty) return 180;
  final lower = restTime.toLowerCase();
  final minMatch = RegExp(r'(\d+)\s*min').firstMatch(lower);
  if (minMatch != null) return (int.tryParse(minMatch.group(1) ?? '') ?? 0) * 60;
  final secMatch = RegExp(r'(\d+)\s*s').firstMatch(lower);
  if (secMatch != null) return int.tryParse(secMatch.group(1) ?? '') ?? 180;
  final numMatch = RegExp(r'~?\s*(\d+)').firstMatch(restTime);
  if (numMatch != null) return (int.tryParse(numMatch.group(1) ?? '') ?? 3) * 60;
  return 180;
}

/// Laadt de rusttijd in seconden voor een oefening uit oefeninglijst.json.
/// Gebruikt het "timer" veld [minuten, seconden]; fallback 180 (3 min) als niet gevonden.
Future<int> getRestTimerSecondsForExercise(String exerciseName) async {
  try {
    final json = await rootBundle.loadString('lib/workouts_info/oefeninglijst.json');
    final data = jsonDecode(json) as Map<String, dynamic>;
    final list = data['exerciseList'] as List<dynamic>? ?? [];
    final nameTrimmed = exerciseName.trim();
    for (final entry in list) {
      final map = entry as Map<String, dynamic>;
      final exercises = map['exercises'] as List<dynamic>? ?? [];
      for (final e in exercises) {
        final exMap = e as Map<String, dynamic>;
        final name = (exMap['name'] as String? ?? '').trim();
        if (name != nameTrimmed) continue;
        final timer = exMap['timer'] as List<dynamic>?;
        if (timer != null && timer.length >= 2) {
          final min = (timer[0] as num?)?.toInt() ?? 0;
          final sec = (timer[1] as num?)?.toInt() ?? 0;
          return min * 60 + sec;
        }
        return 180;
      }
    }
  } catch (_) {}
  return 180;
}
