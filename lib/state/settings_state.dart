import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/strings.dart';

/// Theme mode and UI language, persisted on the device.
///
/// The Quran text, the adhkar and the prayer names are always Arabic —
/// those are the words themselves, not chrome. Only the interface around
/// them is translated.
class SettingsState extends ChangeNotifier {
  static const _themeKey = 'settings_theme_mode';
  static const _localeKey = 'settings_locale';
  static const _hapticsKey = 'settings_haptics';
  static const _soundKey = 'settings_sound';
  static const _translationKey = 'settings_show_translation';
  static const _prayerAlertsKey = 'settings_prayer_alerts';

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('ar');

  /// Feedback on each tasbih tap. On by default — the counter is used with
  /// the screen barely looked at, and the buzz is what confirms the tap.
  bool _haptics = true;
  bool _sound = false;

  /// Whether the dhikr screen shows the book's English rendering under the
  /// Arabic. Off by default: the Arabic is the dhikr, and the translation is
  /// there for whoever wants it rather than in everyone's way.
  bool _showTranslation = false;

  /// On-device prayer-time reminders. Off until the user asks, since it
  /// needs an OS permission.
  bool _prayerAlerts = false;


  bool get haptics => _haptics;
  bool get sound => _sound;
  bool get showTranslation => _showTranslation;
  bool get prayerAlerts => _prayerAlerts;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  AppStrings get strings => AppStrings.of(_locale.languageCode);

  /// True when the app is currently painting dark, resolving `system`
  /// against the platform.
  bool isDark(BuildContext context) => switch (_themeMode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString(_themeKey);
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == theme,
      orElse: () => ThemeMode.system,
    );
    final code = prefs.getString(_localeKey);
    if (code != null && AppStrings.supports(code)) _locale = Locale(code);
    _haptics = prefs.getBool(_hapticsKey) ?? true;
    _sound = prefs.getBool(_soundKey) ?? false;
    _showTranslation = prefs.getBool(_translationKey) ?? false;
    _prayerAlerts = prefs.getBool(_prayerAlertsKey) ?? false;
    notifyListeners();
  }

  /// Cycles light → dark → follow the system, which is the order a single
  /// toggle button can express without a menu.
  Future<void> toggleTheme() async {
    _themeMode = switch (_themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeMode.name);
  }

  Future<void> setHaptics(bool value) async {
    _haptics = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsKey, value);
  }

  Future<void> setSound(bool value) async {
    _sound = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, value);
  }

  Future<void> setShowTranslation(bool value) async {
    _showTranslation = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_translationKey, value);
  }

  Future<void> setPrayerAlerts(bool value) async {
    _prayerAlerts = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prayerAlertsKey, value);
  }


  Future<void> setLocale(String code) async {
    if (!AppStrings.supports(code)) return;
    _locale = Locale(code);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, code);
  }
}
