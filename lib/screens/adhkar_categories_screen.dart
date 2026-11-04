import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/adhkar_data.dart';
import '../state/app_state.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import '../utils/nav.dart';
import '../utils/arabic_numerals.dart';
import 'dhikr_screen.dart';

/// The full adhkar catalogue on its own page.
///
/// It used to be inlined into the More screen, where nine tiles pushed the
/// settings below the fold and made a settings page read as a list of
/// adhkar. One tile there now opens this.
class AdhkarCategoriesScreen extends StatelessWidget {
  const AdhkarCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final strings = context.watch<SettingsState>().strings;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(strings.adhkarSection, style: pageTitle()),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: catalog.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final meta = catalog[i];
          final items = adhkarSets[meta.key]!;
          final done = app.completedCount(meta.key);
          return Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                fadeThrough(DhikrScreen(categoryKey: meta.key),
              )),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: meta.tint.withOpacity(.12),
                      ),
                      child: Icon(meta.icon, size: 22, color: meta.tint),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.category(meta.key),
                              style: uiFont(
                                  size: 18, weight: FontWeight.w600, color: AppColors.ink)),
                          const SizedBox(height: 2),
                          fractionText(done, items.length, size: 13, color: AppColors.ink3),
                        ],
                      ),
                    ),
                    Icon(forwardChevron, size: 22, color: AppColors.ink3),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
