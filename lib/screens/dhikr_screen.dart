import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../data/adhkar_data.dart';
import '../state/app_state.dart';
import '../state/settings_state.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../utils/arabic_numerals.dart';
import '../widgets/ring_counter.dart';

/// Full-screen reading + counting experience for one category. Always
/// light background regardless of category (evening/sleep included) —
/// a dark variant was tried and explicitly reverted, keep it this way.
class DhikrScreen extends StatefulWidget {
  final String categoryKey;
  const DhikrScreen({super.key, required this.categoryKey});

  @override
  State<DhikrScreen> createState() => _DhikrScreenState();
}

class _DhikrScreenState extends State<DhikrScreen> {
  late int idx;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    // Opening a category that is already finished means "let me read it
    // again" — so it starts over from a clean count rather than showing a
    // wall of ticked-off items.
    final list = adhkarSets[widget.categoryKey]!;
    if (app.completedCount(widget.categoryKey) >= list.length) {
      app.resetCategory(widget.categoryKey);
    }
    idx = app.firstOpenIndex(widget.categoryKey);
  }

  String _title(AppStrings strings) {
    switch (widget.categoryKey) {
      case 'morning':
        return strings.morningAdhkar;
      case 'evening':
        return strings.eveningAdhkar;
      default:
        return strings.category(widget.categoryKey);
    }
  }

  void _tapCounter(AppState app) {
    final list = adhkarSets[widget.categoryKey]!;
    final justFinished = app.decrement(widget.categoryKey, idx);
    if (justFinished && idx < list.length - 1) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => idx++);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final settings = context.watch<SettingsState>();
    final strings = settings.strings;
    final list = adhkarSets[widget.categoryKey]!;
    final item = list[idx];
    final left = app.remaining[widget.categoryKey]![idx];

    // This screen has no AppBar to set the overlay style for it, and the
    // home screen's sky leaves the status bar light — force it back to dark
    // for this pale page.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            setState(() {
              if (v < 0 && idx < list.length - 1) idx++; // swipe left → next
              if (v > 0 && idx > 0) idx--; // swipe right → previous
            });
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _backButton(context),
                    Text(_title(strings),
                        style: pageTitle().copyWith(fontSize: 18)),
                    fractionText(idx + 1, list.length, size: 15, color: AppColors.ink3),
                  ],
                ),
              ),
              Expanded(
                // Scrollable, and centred only while it fits: the counter got
                // taller and the longest adhkar then ran off the bottom of a
                // fixed box with nowhere to go.
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.sizeOf(context).height * 0.28,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.text,
                              textAlign: TextAlign.center,
                              style: quranFont(
                                  size: item.text.length > 150 ? 19 : 25, height: 2.15)),
                          if (item.note.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(item.note, style: uiFont(size: 14, color: AppColors.ink3)),
                          ],
                          // Under the Arabic, never beside or instead of it:
                          // the Arabic is the dhikr, this is the book's
                          // English rendering of it.
                          if (settings.showTranslation &&
                              item.translation.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Divider(color: AppColors.line, height: 1),
                            const SizedBox(height: 16),
                            Text(strings.englishTranslation,
                                style: uiFont(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: AppColors.ink3)),
                            const SizedBox(height: 8),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                item.translation,
                                textAlign: TextAlign.center,
                                style: uiFont(
                                    size: 16, color: AppColors.ink2, height: 1.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // A full-width Row so the Stack spans the screen and the
                    // ring stays centred on it, whatever sits beside it.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RingCounter(
                            remaining: left,
                            total: item.count,
                            onTap: () => _tapCounter(app)),
                      ],
                    ),
                    // Vibration and sound sit here rather than in settings:
                    // they are decided while counting — in a quiet room, or
                    // with the phone in a pocket — and that decision should
                    // not cost a trip to another screen. Stacked at the far
                    // edge, and Positioned rather than PositionedDirectional
                    // so they stay on the physical left in any language,
                    // clear of both the dhikr and the misbaha.
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                          child: _feedbackToggles(
                              hasTranslation: item.translation.isNotEmpty)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                child: Row(children: [
                  Expanded(child: _navButton(strings.previous, idx > 0, () => setState(() => idx--))),
                  const SizedBox(width: 12),
                  Expanded(child: _navButton(strings.next, idx < list.length - 1, () => setState(() => idx++), primary: true)),
                ]),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _feedbackToggles({bool hasTranslation = false}) {
    final settings = context.watch<SettingsState>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Only offered where there is something to show. Most adhkar have
        // the book's English; a few do not, and a dead button is worse than
        // no button.
        if (hasTranslation) ...[
          _feedbackToggle(
            icon: LucideIcons.languages,
            on: settings.showTranslation,
            onTap: () =>
                settings.setShowTranslation(!settings.showTranslation),
          ),
          const SizedBox(height: 6),
        ],
        // Vibration and sound stay two separate toggles, each flipped on its
        // own — the choice is made while counting, in a quiet room or with
        // the phone in a pocket.
        _feedbackToggle(
          icon: LucideIcons.vibrate,
          on: settings.haptics,
          onTap: () => settings.setHaptics(!settings.haptics),
        ),
        const SizedBox(height: 6),
        _feedbackToggle(
          icon: LucideIcons.volume2,
          on: settings.sound,
          onTap: () => settings.setSound(!settings.sound),
        ),
      ],
    );
  }

  /// On is a gold glyph on a soft gold disc, off is a grey glyph on nothing.
  /// Both keep the same shape so the pair reads as one control with two
  /// states rather than as two different buttons.
  Widget _feedbackToggle({
    required IconData icon,
    required bool on,
    required VoidCallback onTap,
  }) {
    return Material(
      color: on ? AppColors.gold.withOpacity(.12) : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          // The toggle answers with the thing it controls: turning vibration
          // on buzzes once, so the setting is confirmed by feel.
          if (!on) HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: 42,
          height: 42,
          child:
              Icon(icon, size: 21, color: on ? AppColors.gold : AppColors.ink3),
        ),
      ),
    );
  }

  Widget _backButton(BuildContext context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      );

  /// The two footer actions. «Previous» is a plain outline; «next» is the
  /// step you take most, so it carries a soft gold fill.
  Widget _navButton(String label, bool enabled, VoidCallback onTap,
      {bool primary = false}) {
    final child = Text(label,
        style: uiFont(
            size: 16,
            weight: FontWeight.w600,
            color: enabled ? AppColors.ink : AppColors.ink3));
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
    if (primary) {
      return TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.gold.withOpacity(enabled ? .10 : .04),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: shape,
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
            color: enabled ? AppColors.line : AppColors.line.withOpacity(.5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: shape,
      ),
      child: child,
    );
  }
}
