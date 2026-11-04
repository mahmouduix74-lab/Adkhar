import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/adhkar_data.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import '../utils/arabic_numerals.dart';

/// The "الأذكار" grid: every category (morning/evening included, so
/// they're reachable outside their own time window), 3 per row, each
/// showing a live "done / total" so the grid doubles as a progress
/// overview of the whole day — not just a static menu.
class CategoryGrid extends StatelessWidget {
  final Map<String, List<int>> remainingByKey;
  final void Function(String key) onSelect;

  const CategoryGrid({super.key, required this.remainingByKey, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<SettingsState>().strings;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: .95,
      children: catalog.map((c) {
        final remaining = remainingByKey[c.key]!;
        final total = adhkarSets[c.key]!.length;
        final done = remaining.where((r) => r <= 0).length;
        // "done/total" as a widget so the digits do not flip in RTL; the
        // other two states are plain words.
        final labelText = done == total
            ? strings.completed
            : done == 0
                ? '${ar(total)} ${strings.itemsCount}'
                : null;

        return GestureDetector(
          onTap: () => onSelect(c.key),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
            // No border or check when a category is finished: the adhkar
            // stay open to read again any time. "اكتملت" in the caption is
            // the only marker, and it clears the moment you re-enter.
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(c.icon, size: 26, color: c.tint),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.category(c.key), style: uiFont(size: 16, weight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    labelText != null
                        ? Text(labelText,
                            style: uiFont(size: 13, color: AppColors.ink3))
                        : fractionText(done, total, size: 13, color: AppColors.ink3),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
