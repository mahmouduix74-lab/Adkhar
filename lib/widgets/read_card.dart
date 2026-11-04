import 'package:flutter/material.dart';
import '../data/adhkar_data.dart';
import 'package:provider/provider.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import '../utils/arabic_numerals.dart';
import 'pill_button.dart';

/// The home screen's adhkar preview card — full width, directly under the
/// sky header. Which set it shows is decided by the clock (morning from
/// Fajr to Asr, evening otherwise), so there is only ever one card.
///
/// Deliberately just a *preview*: the first not-yet-finished item, a
/// progress strip, a faded peek at the next line, and a button into the
/// full reading screen.
class ReadCard extends StatelessWidget {
  final String categoryKey;
  final String categoryLabel;
  final List<int> remaining;
  final VoidCallback onOpen;

  const ReadCard({
    super.key,
    required this.categoryKey,
    required this.categoryLabel,
    required this.remaining,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final list = adhkarSets[categoryKey]!;
    final idx = () {
      final i = remaining.indexWhere((r) => r > 0);
      return i == -1 ? 0 : i;
    }();
    final done = remaining.where((r) => r <= 0).length;
    final item = list[idx];
    final next = idx + 1 < list.length ? list[idx + 1].text : '';

    final strings = context.watch<SettingsState>().strings;
    final buttonLabel = done == 0
        ? strings.startAdhkar
        : done == list.length
            ? strings.restartAdhkar
            : strings.continueAdhkar;

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
        // Plain white, no gradient and no stroke — the grey page behind it
        // is what makes it read as a card, and every card in the app uses
        // the same treatment now.
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 9),
                  Text(categoryLabel,
                      style: uiFont(size: 19, weight: FontWeight.w600, color: AppColors.ink)),
                ]),
                Row(children: [
                  fractionText(done, list.length,
                      size: 17, weight: FontWeight.w600, color: AppColors.ink2),
                  const SizedBox(width: 9),
                  _dots(list.length, idx),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            Text(item.text,
                textAlign: TextAlign.center,
                style: quranFont(size: item.text.length > 110 ? 18 : 21, height: 1.85)),
            if (next.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(next,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  style: quranFont(size: 17, color: AppColors.ink.withOpacity(.15))),
            ],
            const SizedBox(height: 14),
            Center(
              child: PillButton(
                hug: true,
                label: buttonLabel,
                onTap: onOpen,
                background: AppColors.gold,
                foreground: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots(int total, int idx) {
    final n = total < 7 ? total : 7;
    final activeDot = (idx / total * n).floor();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(n, (d) {
        final on = d == activeDot;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: on ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: on ? AppColors.gold : AppColors.ink3.withOpacity(.3),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}
