import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../state/settings_state.dart';
import '../theme.dart';

/// The floating bottom navigation: one frosted pill holding all four items,
/// unlabelled, evenly spaced.
///
/// The assistant lives in the bar with the rest rather than in its own
/// floating button — a separate circle left the bar looking lopsided, and a
/// solid fill made it shout. It is marked instead by a thin gradient ring,
/// which says "this one is different" without adding a block of colour.
///
/// Icons are Iconsax, which is the family in the reference: rounded
/// geometric shapes with the same soft interior curve. It also ships a
/// `linear` and a `bold` cut of every glyph, so a tab can go from stroke to
/// solid on selection without the shape appearing to change — which is what
/// happens if the two states come from different families.
class FooterNav extends StatelessWidget {
  static const double _iconSize = 22;
  static const double _barHeight = 62;

  /// The assistant's ring. Violet through teal reads as "AI" without
  /// borrowing the app's gold, which everywhere else means "your progress".
  static const _ringColors = [
    Color(0xFF8B5CF6),
    Color(0xFF3B82F6),
    Color(0xFF2DD4BF),
    Color(0xFF8B5CF6),
  ];

  final String active; // 'home' | 'timeline' | 'more' | 'chat'
  final VoidCallback onHome;
  final VoidCallback onTimeline;
  final VoidCallback onMore;
  final VoidCallback onChat;

  const FooterNav({
    super.key,
    required this.active,
    required this.onHome,
    required this.onTimeline,
    required this.onMore,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<SettingsState>().strings;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        // A Row (not Center/Align) keeps the bar shrink-wrapped vertically —
        // inside Scaffold.bottomNavigationBar an Align would expand to the
        // full screen height and collapse the body to zero.
        child: Row(
          children: [
            Expanded(
              child: _glass(
                child: SizedBox(
                  height: _barHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        _tab(strings.home, IconsaxPlusLinear.home_2,
                            IconsaxPlusBold.home_2, 'home', onHome),
                        // Not `clock`: that glyph is a wristwatch in the
                        // linear cut but a bare dial in the bold one, so the
                        // tab visibly changed shape when you selected it.
                        // `sun_1` is the same silhouette in both cuts — and
                        // the prayer times are set by the sun anyway.
                        _tab(strings.times, IconsaxPlusLinear.sun_1,
                            IconsaxPlusBold.sun_1, 'timeline', onTimeline),
                        // Material's shapes glyph, kept from before the switch
                        // to Iconsax because it is the one that was wanted —
                        // the only icon in this bar not from Iconsax.
                        _tab(strings.more, Icons.category_outlined,
                            Icons.category_rounded, 'more', onMore),
                        if (kAssistantEnabled) _assistantTab(strings.assistant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Frosted glass: a blur of whatever is scrolling underneath, tinted with
  /// a translucent surface. The bar has to stay legible over both a bright
  /// card and a dark sky, and a flat fill could only ever suit one of them.
  Widget _glass({required Widget child}) {
    final radius = BorderRadius.circular(999);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(.78),
            borderRadius: radius,
            border: Border.all(color: AppColors.ink.withOpacity(.06)),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Idle tabs are thin grey strokes; the selected one switches to the solid
  /// version of the same glyph in the accent colour, inside a soft pill.
  /// With no labels, that swap is the whole selection cue.
  Widget _tab(String label, IconData idle, IconData selected, String key,
      VoidCallback onTap) {
    final isActive = active == key;
    return Expanded(
      child: _slot(
        label: label,
        onTap: onTap,
        highlighted: isActive,
        child: Icon(
          isActive ? selected : idle,
          size: _iconSize,
          color: isActive ? AppColors.gold : AppColors.ink3.withOpacity(.8),
        ),
      ),
    );
  }

  Widget _assistantTab(String label) {
    return Expanded(
      child: _slot(
        label: label,
        onTap: onChat,
        highlighted: active == 'chat',
        child: CustomPaint(
          painter: _RingPainter(_ringColors),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(IconsaxPlusLinear.message_question, size: 15, color: _ringColors[1]),
          ),
        ),
      ),
    );
  }

  Widget _slot({
    required String label,
    required VoidCallback onTap,
    required bool highlighted,
    required Widget child,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            height: _barHeight - 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlighted ? AppColors.ink.withOpacity(.05) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A hairline circle stroked with a sweep gradient. Painting the ring rather
/// than stacking two filled circles keeps the bar's blur visible through the
/// middle — a solid inner disc would punch an opaque hole in the glass.
class _RingPainter extends CustomPainter {
  final List<Color> colors;
  const _RingPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = math.min(size.width, size.height) / 2 - 1;
    canvas.drawCircle(
      rect.center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..shader = SweepGradient(colors: colors).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.colors != colors;
}
