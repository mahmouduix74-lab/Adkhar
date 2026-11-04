import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../state/settings_state.dart';
import '../theme.dart';

/// The Mushaf and the qibla, sitting directly under the adhkar grid as two
/// more tiles of the same family.
///
/// The height is derived from the grid's own geometry rather than picked by
/// eye — three columns at [CategoryGrid]'s aspect ratio — so these two line
/// up with the row above them on any screen width instead of matching on
/// the one phone they were checked against.
class ExtraCards extends StatelessWidget {
  final VoidCallback onMushaf;
  final VoidCallback onQibla;

  const ExtraCards({super.key, required this.onMushaf, required this.onQibla});

  /// Must stay in step with CategoryGrid.
  static const double _sidePadding = 16;
  static const double _spacing = 10;
  static const int _gridColumns = 3;
  static const double _gridAspect = .95;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<SettingsState>().strings;
    final width = MediaQuery.sizeOf(context).width;
    final cell = (width - _sidePadding * 2 - _spacing * (_gridColumns - 1)) /
        _gridColumns;

    return Padding(
      padding: const EdgeInsets.fromLTRB(_sidePadding, 0, _sidePadding, 0),
      child: SizedBox(
        height: cell / _gridAspect,
        child: Row(
          children: [
            Expanded(
              child: _card(
                title: strings.mushaf,
                subtitle: strings.openMushaf,
                icon: LucideIcons.bookOpen,
                tint: const Color(0xFF5B8F6D),
                onTap: onMushaf,
              ),
            ),
            const SizedBox(width: _spacing),
            Expanded(
              child: _card(
                title: strings.qibla,
                subtitle: strings.facingMecca,
                icon: LucideIcons.compass,
                tint: const Color(0xFF3D54A0),
                onTap: onQibla,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The two tiles that are not adhkar, so they are allowed to look it: a
  /// glow rising out of the bottom-left corner in the card's own colour.
  ///
  /// Painted inside the card only. An outer coloured shadow was tried
  /// alongside it and dropped — it sat under the card as a shadow rather
  /// than reading as light, and the page is otherwise shadowless.
  Widget _card({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color tint,
    required VoidCallback onTap,
  }) {
    final radius = BorderRadius.circular(18);
    return Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: RadialGradient(
              center: const Alignment(-0.9, 1.05),
              radius: 1.25,
              colors: [
                Color.lerp(AppColors.surface, tint, .22)!,
                AppColors.surface,
              ],
              stops: const [0, .85],
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 26, color: tint),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: uiFont(size: 16, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: uiFont(size: 13, color: AppColors.ink3)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
