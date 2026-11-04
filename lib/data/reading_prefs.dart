import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the reader turns pages. Horizontal is the default — it is what a
/// physical mushaf does, and it keeps the vertical gesture free for
/// scrolling a long surah.
enum ReadingMode { horizontal, vertical }

extension ReadingModeX on ReadingMode {
  Axis get axis => this == ReadingMode.horizontal ? Axis.horizontal : Axis.vertical;
  String label(AppStrings s) =>
      this == ReadingMode.horizontal ? s.horizontal : s.vertical;
}

class ReadingPrefs {
  static const _key = 'mushaf_reading_mode';

  static Future<ReadingMode> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == 'vertical' ? ReadingMode.vertical : ReadingMode.horizontal;
  }

  static Future<void> save(ReadingMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
