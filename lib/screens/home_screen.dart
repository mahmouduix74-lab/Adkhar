import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:provider/provider.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import '../utils/nav.dart';
import '../widgets/sky_hero.dart';
import '../widgets/read_card.dart';
import '../widgets/category_grid.dart';
import '../widgets/extra_cards.dart';
import '../widgets/footer_nav.dart';
import '../widgets/pill_button.dart';
import 'dhikr_screen.dart';
import 'timeline_screen.dart';
import 'mushaf_screen.dart';
import 'qibla_screen.dart';
import 'chat_screen.dart';
import 'more_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Every section is separated by the same gap, and every section header
  /// sits the same distance above its content — change them here, not per
  /// call site, so the page keeps one rhythm.
  static const double _sectionGap = 26;
  static const double _titleGap = 12;

  /// How far the whole page body is lifted into the tail of the sky.
  ///
  /// Lifting the *body* rather than just the card keeps every gap inside it
  /// untouched, so the space above the adhkar card and the space below it
  /// are both exactly [_sectionGap]. Lifting only the card left a phantom
  /// hole underneath it that had to be paid for out of the next header's
  /// padding — and that cap (padding cannot go negative) is what limited
  /// the overlap before.
  static const double _bodyLift = 48;

  final _scroll = ScrollController();

  /// True while the sky is still behind the status bar. The page has no
  /// SafeArea, so once it scrolls away the clock/battery sit on the pale
  /// page colour and have to flip back to dark.
  bool _skyUnderStatusBar = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final under = _scroll.offset < 40;
      if (under != _skyUnderStatusBar) setState(() => _skyUnderStatusBar = under);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openCategory(BuildContext context, String key) {
    Navigator.of(context).push(fadeThrough(DhikrScreen(categoryKey: key)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final strings = context.watch<SettingsState>().strings;
    final key = app.featureKey;
    // The sky is dark at every hour now, so the status bar is light
    // whenever the sky is behind it — no need to ask which prayer it is.
    final lightIcons = _skyUnderStatusBar;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightIcons ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
      // No SafeArea here on purpose: the sky gradient runs edge to edge,
      // up behind the status bar. SkyHero adds the top inset itself.
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkyHero(
              current: app.current,
              next: app.next,
              nowMin: app.nowMin,
              hijriDate: _hijriToday(),
              onTap: () => Navigator.of(context).push(fadeThrough(const TimelineScreen())),
            ),
            // The whole body, lifted as one block into the sky's tail.
            Transform.translate(
              offset: const Offset(0, -_bodyLift),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // One card, picked by the clock: morning from Fajr to Asr,
                  // evening from Asr to the next Fajr (AppState.featureKey).
                  ReadCard(
                    categoryKey: key,
                    categoryLabel: key == 'morning'
                        ? strings.morningAdhkar
                        : strings.eveningAdhkar,
                    remaining: app.remaining[key]!,
                    onOpen: () => _openCategory(context, key),
                  ),
                  _sectionHeader(strings.quranSection, 'الفاتحة'),
                  _quranCard(context, strings),
                  _sectionHeader(strings.adhkarSection),
                  CategoryGrid(
                    remainingByKey: app.remaining,
                    onSelect: (k) => _openCategory(context, k),
                  ),
                  // Their own section under the adhkar, not tacked onto the
                  // grid: they are places to go, not adhkar, and the grid's
                  // count is what says how many categories there are.
                  _sectionHeader(strings.toolsSection),
                  ExtraCards(
                    onMushaf: () => Navigator.of(context).push(
                        fadeThrough(const MushafScreen())),
                    onQibla: () => Navigator.of(context).push(
                        fadeThrough(const QiblaScreen())),
                  ),
                ],
              ),
            ),
            // Restores the scroll extent the lift took away, plus clearance
            // for the floating nav pill.
            const SizedBox(height: 90 + _bodyLift),
          ],
        ),
      ),
      bottomNavigationBar: FooterNav(
        active: 'home',
        onHome: () {},
        onTimeline: () => Navigator.of(context).push(fadeThrough(const TimelineScreen())),
        onMore: () => Navigator.of(context).push(fadeThrough(const MoreScreen())),
        onChat: () => Navigator.of(context).push(fadeThrough(const ChatScreen())),
      ),
      ),
    );
  }

  /// Today in the Umm al-Qura calendar, in Arabic. Computed, not typed —
  /// the old hard-coded string was simply wrong every day after the one it
  /// was written on.
  ///
  /// Umm al-Qura is a tabular calendar; a locally sighted month can start a
  /// day either side of it. It is the standard reference, not a claim about
  /// the moon over any particular place.
  String _hijriToday() {
    final h = HijriCalendar.now();
    final month = h
        .getLongMonthName()
        .replaceAll('الاول', 'الأول')
        .replaceAll('الاخر', 'الآخر');
    return '${_arabicDigits(h.hDay)} $month ${_arabicDigits(h.hYear)}';
  }

  String _arabicDigits(int n) => n
      .toString()
      .split('')
      .map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)])
      .join();

  Widget _sectionHeader(String title, [String? trailing]) => Padding(
        padding: const EdgeInsets.fromLTRB(20, _sectionGap, 20, _titleGap),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: uiFont(size: 20, weight: FontWeight.w600)),
            if (trailing != null) Text(trailing, style: uiFont(size: 14, color: AppColors.ink3)),
          ],
        ),
      );

  Widget _quranCard(BuildContext context, AppStrings strings) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(kCardRadius)),
        child: Column(
          children: [
            Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', textAlign: TextAlign.center, style: quranFont(size: 20, height: 1.8)),
            Text('الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ ﴿١﴾', textAlign: TextAlign.center, style: quranFont(size: 20, height: 1.8)),
            Text('الرَّحْمَٰنِ الرَّحِيمِ ﴿٢﴾ مَالِكِ يَوْمِ الدِّينِ', textAlign: TextAlign.center,
                style: quranFont(size: 20, height: 1.8, color: AppColors.ink.withOpacity(.24))),
            const SizedBox(height: 10),
            PillButton(
              hug: true,
              label: strings.readToday,
              onTap: () => Navigator.of(context).push(fadeThrough(const MushafScreen())),
              background: AppColors.goldSoft,
              foreground: AppColors.ink,
            ),
          ],
        ),
      );
}
