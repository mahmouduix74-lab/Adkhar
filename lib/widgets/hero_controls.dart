import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/notifications.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../state/settings_state.dart';
import '../theme.dart';

/// Theme and language controls, sitting over the sky. They take their colour
/// from the sky's own text colour rather than the palette, because the
/// header can be a dark night sky even while the app is in light mode.
class HeroControls extends StatelessWidget {
  final Color color;
  const HeroControls({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();

    // Pinned to the physical left. A bare Row in an RTL Directionality
    // starts from the right, which is where these ended up the first time.
    return Row(
      children: [
        const Spacer(),
        _button(
          tooltip: settings.strings.appearance,
          icon: switch (settings.themeMode) {
            ThemeMode.light => Icons.light_mode_outlined,
            ThemeMode.dark => Icons.dark_mode_outlined,
            ThemeMode.system => Icons.brightness_auto_outlined,
          },
          onTap: settings.toggleTheme,
        ),
        const SizedBox(width: 6),
        _button(
          tooltip: settings.strings.prayerAlerts,
          icon: settings.prayerAlerts
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          onTap: () => _toggleAlerts(context, settings),
        ),
        const SizedBox(width: 6),
        _button(
          tooltip: settings.strings.language,
          icon: Icons.translate_rounded,
          onTap: () => _pickLanguage(context, settings),
          // The current language's own letter — «ع» in Arabic — rather than
          // the "AR" code, so it reads in the language it switches.
          label: settings.locale.languageCode == 'ar'
              ? 'ع'
              : settings.locale.languageCode.toUpperCase(),
        ),
      ],
    );
  }

  Future<void> _toggleAlerts(BuildContext context, SettingsState settings) async {
    if (settings.prayerAlerts) {
      await PrayerNotifications.instance.cancelAll();
      await settings.setPrayerAlerts(false);
      return;
    }
    final granted = await PrayerNotifications.instance.requestPermission();
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(settings.strings.notifPermissionDenied,
            style: uiFont(size: 14, color: Colors.white)),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    await PrayerNotifications.instance
        .reschedule(context.read<AppState>().schedule);
    await settings.setPrayerAlerts(true);
  }

  Widget _button({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    String? label,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(.12),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: label == null ? 10 : 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  // Sized to sit level with the 20pt glyph beside it. At 13pt
                  // a single Arabic letter — «ع» — read as a smudge next to
                  // the icon rather than as a letter.
                  Text(label,
                      style: uiFont(size: 16, weight: FontWeight.w700, color: color)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context, SettingsState settings) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(settings.strings.language,
                  style: uiFont(size: 19, weight: FontWeight.w600, color: AppColors.ink)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in AppStrings.all)
                    ListTile(
                      onTap: () => Navigator.of(context).pop(s.code),
                      title: Text(s.nativeName,
                          textDirection: s.direction,
                          style: uiFont(size: 17, color: AppColors.ink)),
                      trailing: s.code == settings.locale.languageCode
                          ? Icon(Icons.check_rounded, color: AppColors.gold)
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) await settings.setLocale(chosen);
  }
}
