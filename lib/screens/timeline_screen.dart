import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/prayer.dart';
import '../state/app_state.dart';
import '../l10n/strings.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import '../utils/nav.dart';
import '../widgets/footer_nav.dart';
import 'chat_screen.dart';
import 'more_screen.dart';

/// The day's prayer schedule, kept deliberately quiet.
///
/// There is no summary card: a full-width gradient block at the top took all
/// the attention and left the list — which is the actual content — looking
/// secondary. What is coming next is said in plain type instead.
///
/// Every prayer is a rounded row of its own; the next one is the same shape
/// filled with the primary colour, so the highlight is a change of fill
/// rather than a change of kind.
///
/// Every prayer reads the same whether it has passed or not. Ticking off the
/// earlier ones and greying them made the day look like a checklist of
/// missed things, which is not what a times screen is for.
class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  static const _icons = {
    // One continuous arc of the same sun, from Lucide so these match the
    // stroke icons used everywhere else. Material's set had العصر on a cloud,
    // which says nothing about the hour, and gave الضحى and المغرب the same
    // twilight glyph — two different ends of the day drawn identically.
    'الفجر': LucideIcons.sunrise,
    // Lucide's three suns are a size ramp, so they are assigned by how high
    // the sun actually is: faint at الضحى, full at الظهر, half again at
    // العصر. Ordered any other way two adjacent rows carry the same glyph.
    'الضحى': LucideIcons.sunDim,
    'الظهر': LucideIcons.sun,
    'العصر': LucideIcons.sunMedium,
    'المغرب': LucideIcons.sunset,
    'العشاء': LucideIcons.moonStar,
  };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final settings = context.watch<SettingsState>();
    final schedule = app.schedule;
    final next = app.next;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.paper,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(settings.strings.prayerTimes, style: pageTitle()),
          ),
          SliverToBoxAdapter(
            child: _upNext(next, settings.strings.nextPrayer, settings.strings),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            sliver: SliverList.separated(
              itemCount: schedule.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _row(
                schedule[i],
                settings.strings,
                isNext: schedule[i].name == next.name,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: FooterNav(
        active: 'timeline',
        onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
        onTimeline: () {},
        onMore: () => Navigator.of(context)
            .push(fadeThrough(const MoreScreen())),
        onChat: () => Navigator.of(context)
            .push(fadeThrough(const ChatScreen())),
      ),
    );
  }

  /// What is coming, said in type rather than in a coloured block.
  Widget _upNext(Prayer next, String heading, AppStrings strings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: uiFont(size: 14, color: AppColors.ink3)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(strings.prayer(next.name),
                  style: uiFont(size: 28, weight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(next.time,
                    style: uiFont(size: 20, weight: FontWeight.w600, color: AppColors.gold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Every row is the same white pill. The next prayer is marked by colour
  /// on its own type and icon only — filling the whole row made one line
  /// shout over a list whose job is to be read at a glance.
  Widget _row(Prayer prayer, AppStrings strings, {required bool isNext}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              strings.prayer(prayer.name),
              style: uiFont(
                size: 18,
                weight: isNext ? FontWeight.w700 : FontWeight.w500,
                color: isNext ? AppColors.gold : AppColors.ink,
              ),
            ),
          ),
          Icon(_icons[prayer.name] ?? LucideIcons.clock,
              size: 21, color: isNext ? AppColors.gold : AppColors.ink3),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                prayer.time,
                style: uiFont(
                  size: 17,
                  weight: isNext ? FontWeight.w700 : FontWeight.w500,
                  color: isNext ? AppColors.gold : AppColors.ink2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
