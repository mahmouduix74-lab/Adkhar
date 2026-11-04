import 'package:flutter/material.dart';
import '../theme.dart';

/// The one button shape used across the app. Every call site gets the same
/// width, height, type size and forward-pointing chevron — variants may only
/// change colour, never metrics, so the buttons on the home screen line up
/// with each other and with the one in the sky header.
class PillButton extends StatelessWidget {
  static const double _defaultWidth = 214;
  static const double _height = 50;
  static const double _fontSize = 17;

  final String label;
  final VoidCallback? onTap;

  /// Fill. Leave transparent and pass [borderColor] for the outlined variant.
  final Color background;
  final Color foreground;
  final Color? borderColor;

  /// Overrides the shared width. Only pass this when a button genuinely
  /// needs to be tighter than the others — the default exists so the
  /// buttons across the app line up.
  final double? width;

  /// Sizes to the label instead of the shared width, with just enough
  /// padding to breathe. Use it where the button is an aside rather than a
  /// peer of the other buttons.
  final bool hug;

  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.foreground,
    this.background = Colors.transparent,
    this.borderColor,
    this.width,
    this.hug = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: hug ? null : (width ?? _defaultWidth),
      height: _height,
      child: Material(
        color: background,
        shape: StadiumBorder(
          side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hug ? 16 : 10),
            child: Row(
              mainAxisSize: hug ? MainAxisSize.min : MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Flexible + scaleDown, not a bare Text: the width is fixed so
                // every button matches, and a long label (or a fallback font
                // with wider metrics) must shrink rather than overflow.
                // A hugging button is already sized to its label, so it must
                // not be Flexible — that would let it shrink to nothing.
                if (hug)
                  Text(label,
                      maxLines: 1,
                      style: uiFont(size: _fontSize, weight: FontWeight.w600, color: foreground))
                else
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: uiFont(size: _fontSize, weight: FontWeight.w600, color: foreground),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(forwardChevron, size: 24, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
