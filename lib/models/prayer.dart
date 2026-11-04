import 'package:flutter/material.dart';
import '../utils/arabic_numerals.dart';

/// One of the six daily prayer times, plus the sky-gradient colors
/// and body-text color the home screen uses while that prayer is
/// the "current" one. [minutes] is minutes-since-midnight, used for
/// all "which prayer are we in" math.
class Prayer {
  final String name;
  final int minutes;

  /// Formatted at read time, not stored. Baking the string when the day's
  /// schedule was computed froze it in whatever digits were active then —
  /// switching the app to English left "٦:٣٥ ص" on the arc.
  String get time => formatClock(minutes ~/ 60, minutes % 60);
  final Color c1, c2, c3;
  final bool light; // true = dark text on a pale sky (e.g. midday)

  const Prayer({
    required this.name,
    required this.minutes,
    required this.c1,
    required this.c2,
    required this.c3,
    this.light = false,
  });
}
