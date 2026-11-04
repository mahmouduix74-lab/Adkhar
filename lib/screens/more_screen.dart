import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../data/notifications.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import '../utils/nav.dart';
import '../widgets/footer_nav.dart';
import 'chat_screen.dart';
import 'timeline_screen.dart';

/// Everything that does not belong on the home screen: the full adhkar
/// catalogue, the mushaf, and the app's settings in one place.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final strings = settings.strings;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(strings.more, style: pageTitle()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _sectionLabel(strings.appearance),
          _tile(
            icon: switch (settings.themeMode) {
              ThemeMode.light => Icons.light_mode_outlined,
              ThemeMode.dark => Icons.dark_mode_outlined,
              ThemeMode.system => Icons.brightness_auto_outlined,
            },
            title: strings.appearance,
            trailing: switch (settings.themeMode) {
              ThemeMode.light => strings.light,
              ThemeMode.dark => strings.dark,
              ThemeMode.system => strings.systemMode,
            },
            onTap: settings.toggleTheme,
          ),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.translate_rounded,
            title: strings.language,
            trailing: AppStrings.of(settings.locale.languageCode).nativeName,
            onTap: () => _pickLanguage(context, settings),
          ),
          const SizedBox(height: 8),
          _tile(
            icon: settings.prayerAlerts
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            title: strings.prayerAlerts,
            trailing: settings.prayerAlerts ? '✓' : '',
            onTap: () => _toggleAlerts(context, settings),
          ),
          const SizedBox(height: 22),
          _sectionLabel(strings.contactUs),
          _tile(
            // No WhatsApp wordmark is bundled — the brand's green on a plain
            // message bubble says which app it opens without shipping someone
            // else's logo.
            icon: IconsaxPlusBold.message_circle,
            iconColour: const Color(0xFF25D366),
            title: strings.whatsapp,
            onTap: () => _openWhatsApp(context),
          ),
          const SizedBox(height: 22),
          // Where the content comes from. A reader of a worship app is
          // entitled to know, and it keeps us honest about what is sourced.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.sources,
                    style: uiFont(size: 16, weight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 8),
                // One line per thing, each naming where it actually comes
                // from. The text used to be credited to Tanzil along with
                // the boundaries; it is not — the boundaries are Tanzil's,
                // the text ships with the `quran` package, and the two are
                // the same words in different Uthmani renderings. Crediting
                // a source you did not use is worse than crediting none.
                _source(strings.srcQuranText, 'quran (pub.dev) — Uthmani'),
                _source(strings.srcBoundaries, 'Tanzil.net'),
                _source(strings.srcAdhkar, 'hisnmuslim.com'),
                _source(strings.srcTafsir,
                    'التفسير الميسّر (كامل، أوفلاين) — alquran.cloud / KSU'),
                _source(strings.srcHadith,
                    'hadith-api (CC0) — المتن فقط'),
                _source(strings.srcTranslation,
                    'Quran Foundation (quran.com) — مجمع الملك فهد وجهات رسمية'),
                _source(strings.srcRecitation, 'مشاري العفاسي — islamic.network'),
                _source(strings.srcTimes, strings.srcTimesValue),
                _source(strings.srcQiblaLine, strings.srcQiblaValue),
                const SizedBox(height: 12),
                Text(
                  strings.sourcesNote,
                  style: uiFont(size: 13, color: AppColors.ink3, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FooterNav(
        active: 'more',
        onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
        onTimeline: () => Navigator.of(context)
            .push(fadeThrough(const TimelineScreen())),
        onMore: () {},
        onChat: () => Navigator.of(context)
            .push(fadeThrough(const ChatScreen())),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(text,
            style: uiFont(size: 15, weight: FontWeight.w600, color: AppColors.ink3)),
      );

  /// One "what: where from" line. Kept as its own row rather than a
  /// paragraph so a source can be added or corrected without re-flowing a
  /// block of prose in ten languages.
  Widget _source(String what, String from) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(
                text: '$what: ',
                style: uiFont(
                    size: 14, weight: FontWeight.w600, color: AppColors.ink2)),
            TextSpan(text: from, style: uiFont(size: 14, color: AppColors.ink3)),
          ]),
        ),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? trailing,
    Color? iconColour,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(icon, size: 23, color: iconColour ?? AppColors.gold),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title,
                    style: uiFont(size: 17, weight: FontWeight.w600, color: AppColors.ink)),
              ),
              if (trailing != null)
                Text(trailing, style: uiFont(size: 15, color: AppColors.ink3)),
              const SizedBox(width: 6),
              Icon(forwardChevron, size: 22, color: AppColors.ink3),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the chat directly on the app's number. `wa.me` is WhatsApp's own
  /// entry point: it hands off to the installed app, and falls back to the
  /// browser when there isn't one — so this works on a bare device too.
  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/$kWhatsAppNumber');
    final opened =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('+$kWhatsAppNumber',
          textDirection: TextDirection.ltr,
          style: uiFont(size: 15, color: Colors.white)),
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _toggleAlerts(
      BuildContext context, SettingsState settings) async {
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
