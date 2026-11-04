import 'dart:async';
import 'package:adhan/adhan.dart' show Coordinates;
import 'package:flutter/material.dart';
import '../data/adhkar_data.dart';
import '../data/prayer_data.dart';
import '../models/prayer.dart';

/// Single source of truth for the whole app: the real prayer schedule for
/// wherever the device is, the real current time, and how many of each
/// dhikr the user has completed.
///
/// The schedule is computed offline by the `adhan` package — only the
/// coordinates come from the OS, and even those have a fallback city, so
/// the app always has a schedule to show.
class AppState extends ChangeNotifier {
  AppState() {
    _rebuildSchedule(fallbackCoordinates);
    _startClock();
    _locate();
  }

  Timer? _clock;
  Coordinates _coordinates = fallbackCoordinates;
  late List<Prayer> _schedule;

  /// True once real device coordinates replaced the fallback city.
  bool usingDeviceLocation = false;

  /// Minutes since midnight, from the device clock.
  int nowMin = _minutesNow();

  List<Prayer> get schedule => _schedule;

  /// Where the schedule — and the qibla — are computed for. Falls back to a
  /// city rather than to nothing, so both always have an answer.
  Coordinates get coordinates => _coordinates;

  static int _minutesNow() {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  void _rebuildSchedule(Coordinates coordinates) {
    _coordinates = coordinates;
    _schedule = buildSchedule(computeTimes(coordinates, DateTime.now()));
  }

  /// Ticks once a minute so the arc, the countdown and the sky colour keep
  /// up with the clock without the UI having to poll.
  void _startClock() {
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      final minutes = _minutesNow();
      if (minutes == nowMin) return;
      // Crossing midnight means yesterday's schedule is stale.
      if (minutes < nowMin) _rebuildSchedule(_coordinates);
      nowMin = minutes;
      notifyListeners();
    });
  }

  Future<void> _locate() async {
    final coordinates = await deviceCoordinates();
    if (coordinates == null) return;
    _rebuildSchedule(coordinates);
    usingDeviceLocation = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// remaining[category][index] = how many reps are left for that dhikr.
  final Map<String, List<int>> remaining = {
    for (final entry in adhkarSets.entries)
      entry.key: entry.value.map((d) => d.count).toList(),
  };

  Prayer get current => currentPrayer(_schedule, nowMin);
  Prayer get next => nextPrayer(_schedule, nowMin);

  /// Which adhkar the home card shows: morning from Fajr until Asr, evening
  /// from Asr until the next Fajr.
  String get featureKey {
    final fajr = _schedule.first.minutes;
    final asr = _schedule[3].minutes;
    return (nowMin >= fajr && nowMin < asr) ? 'morning' : 'evening';
  }

  int completedCount(String key) => remaining[key]!.where((r) => r <= 0).length;

  /// First not-yet-finished index in [key], or 0 if the whole list is done.
  int firstOpenIndex(String key) {
    final i = remaining[key]!.indexWhere((r) => r > 0);
    return i == -1 ? 0 : i;
  }

  /// Tap the counter for item [index] in [key]. Returns true once that item
  /// just reached zero, so the caller can auto-advance after a beat.
  bool decrement(String key, int index) {
    if (remaining[key]![index] <= 0) return false;
    remaining[key]![index]--;
    notifyListeners();
    return remaining[key]![index] == 0;
  }

  void resetCategory(String key) {
    remaining[key] = adhkarSets[key]!.map((d) => d.count).toList();
    notifyListeners();
  }

  /// Preview aid on the timeline screen: step through the day's windows to
  /// see the sky and arc change. Snaps back to the real clock on the next
  /// tick, so it can never leave the app showing a wrong time for long.
  void advanceDemoTime() {
    final marks = _schedule.map((p) => p.minutes).toList()..sort();
    nowMin = marks.firstWhere((m) => m > nowMin, orElse: () => marks.first);
    notifyListeners();
  }
}
