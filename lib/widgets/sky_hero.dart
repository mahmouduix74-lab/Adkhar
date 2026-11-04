import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, lerpDouble;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prayer.dart';
import '../l10n/strings.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import 'hero_controls.dart';
import 'pill_button.dart';
import '../utils/arabic_numerals.dart';

/// The gradient "sky" header: seamlessly blends from the current
/// prayer's night/day color into the page background (no hard edge —
/// see the last gradient stop below), with a semicircular arc showing
/// how far we are between the current prayer and the next one.
///
/// Tapping anywhere on the hero opens the full prayer-times timeline —
/// wire [onTap] to that navigation.
class SkyHero extends StatefulWidget {
  final Prayer current;
  final Prayer next;
  final int nowMin;
  final String hijriDate;
  final VoidCallback onTap;

  const SkyHero({
    super.key,
    required this.current,
    required this.next,
    required this.nowMin,
    required this.hijriDate,
    required this.onTap,
  });

  @override
  State<SkyHero> createState() => _SkyHeroState();
}

class _SkyHeroState extends State<SkyHero> {
  /// The centre of the arc is a live countdown, so this ticks every second.
  /// AppState's own timer is coarser (it only needs to notice the minute
  /// and the window changing) — driving seconds from here keeps the rest of
  /// the app from rebuilding sixty times a minute.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Prayer get current => widget.current;
  Prayer get next => widget.next;
  int get nowMin => widget.nowMin;
  String get hijriDate => widget.hijriDate;
  VoidCallback get onTap => widget.onTap;

  /// Seconds until the next prayer, from the wall clock rather than from
  /// [nowMin] — the big counter has to move every second, not every minute.
  int get _secondsToNext {
    final now = DateTime.now();
    final nowSeconds = now.hour * 3600 + now.minute * 60 + now.second;
    final target = next.minutes * 60;
    final delta = target - nowSeconds;
    return delta <= 0 ? delta + 86400 : delta;
  }

  /// "١:٢١:٠٥" — hours only when there are any.
  String get _countdown {
    final total = _secondsToNext;
    final h = total ~/ 3600, m = (total % 3600) ~/ 60, sec = total % 60;
    String two(int v) => ar(v.toString().padLeft(2, '0'));
    return h > 0 ? '${ar(h)}:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  /// Minutes from [from] forward to [to], wrapping over midnight. Every
  /// span here can straddle midnight — during Isha the window started
  /// yesterday and ends at tomorrow's Fajr — so plain subtraction gives
  /// either a negative age or a ~24h countdown.
  static int _forward(int from, int to) {
    final delta = to - from;
    return delta < 0 ? delta + 1440 : delta;
  }

  /// How far through the current window we are, 0..1.
  double get _progress {
    final span = _forward(current.minutes, next.minutes);
    if (span == 0) return 0;
    return (_forward(current.minutes, nowMin) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // Always white: every sky gradient is deep enough to carry it, so the
    // header never flips to dark type halfway through the day.
    const textColor = Color(0xFFFFFFFF);
    final strings = context.watch<SettingsState>().strings;
    // Derived from the same seconds the counter uses, so the two never
    // disagree by a minute mid-tick.
    final remainMin = _secondsToNext ~/ 60;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        // Top padding carries the status-bar inset itself (the page has no
        // SafeArea) plus breathing room. The deep bottom padding is the
        // point of the sky: it gives the gradient a long tail to dissolve
        // into the page colour, so it reads as a sky, not a coloured band.
        // viewPadding, not padding: `padding` is zeroed by any ancestor that
        // has already consumed the inset (Scaffold does, for a body with no
        // SafeArea), which put these controls inside the status bar.
        // viewPadding always reports the physical notch inset.
        padding: EdgeInsets.fromLTRB(20, MediaQuery.viewPaddingOf(context).top + 14, 20, 74),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [current.c1, current.c2, current.c3, AppColors.paper],
            // The fade is pushed late on purpose: the card below is lifted
            // into this tail, so there has to be real colour left where its
            // top edge lands, not just the last few pixels of a dissolve.
            stops: const [0.0, 0.40, 0.80, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Theme and language sit over the sky, above everything else.
            HeroControls(color: textColor),
            const SizedBox(height: 4),
            // One block: the arch, the date/time/name inside it, the two
            // prayer labels tucked under each arc end, and the countdown
            // line sitting in the free space between those labels.
            SizedBox(
              width: 356,
              height: 214,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _ArcPainter(progress: _progress, color: textColor)),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 62,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(hijriDate,
                            textAlign: TextAlign.center,
                            style: uiFont(size: 15, weight: FontWeight.w500, color: textColor.withOpacity(.8))),
                        const SizedBox(height: 4),
                        // A live countdown to the next prayer. The prayer's
                        // name and clock time live at the arc's ends, so
                        // repeating them here would only crowd the centre.
                        Text(_countdown,
                            textAlign: TextAlign.center,
                            style: uiFont(size: 52, weight: FontWeight.w700, color: textColor)
                                .copyWith(letterSpacing: 0, height: 1, fontFeatures: const [
                              // Tabular figures: without them the counter
                              // jitters sideways as the digits change.
                              FontFeature.tabularFigures(),
                            ])),
                      ],
                    ),
                  ),
                  // Arc start — the current prayer.
                  Positioned(right: 0, bottom: 0, child: _legend(strings.prayer(current.name), current.time, textColor)),
                  // Arc end — the next prayer.
                  Positioned(left: 0, bottom: 0, child: _legend(strings.prayer(next.name), next.time, textColor)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Below the arc, not inside it: the two prayer labels are wide
            // enough now that a line squeezed between them collided with them.
            Text.rich(
              textAlign: TextAlign.center,
              TextSpan(style: uiFont(size: 14, color: textColor.withOpacity(.9)), children: [
                TextSpan(text: '${strings.remaining} '),
                TextSpan(text: _remaining(remainMin, strings),
                    style: uiFont(size: 14, weight: FontWeight.w700, color: textColor)),
                TextSpan(text: ' ${strings.until} ${strings.prayer(next.name)}'),
              ]),
            ),
            const SizedBox(height: 12),
            PillButton(
              hug: true,
              label: strings.prayerTimes,
              onTap: onTap,
              foreground: textColor,
              borderColor: textColor.withOpacity(.8),
            ),
          ],
        ),
      ),
    );
  }

  /// "٥٥ دقيقة" / "١ ساعة و٥ دقيقة" — the countdown to the next prayer.
  String _remaining(int minutes, AppStrings strings) {
    final h = minutes ~/ 60, m = minutes % 60;
    final hours = strings.get('hours'), mins = strings.get('minutes');
    return h > 0 ? '${ar(h)} $hours ${ar(m)} $mins' : '${ar(m)} $mins';
  }

  /// A prayer label under one end of the arc. Both lines are centred on
  /// each other and the whole block is centred on the arc's end point, so
  /// the label reads as belonging to that end.
  Widget _legend(String name, String time, Color color) {
    return SizedBox(
      width: _kLegendWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(name,
              textAlign: TextAlign.center,
              style: uiFont(size: 14, weight: FontWeight.w500, color: color.withOpacity(.75))),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(time,
                maxLines: 1,
                style: uiFont(size: 19, weight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}

/// Rendered height of one `_legend` block (name + 2px gap + time). The arc
/// ends sit above it, so the two must stay in sync.
const double _kLegendHeight = 47;

/// Breathing room between where the arc ends and the label under it.
const double _kLegendGap = 12;

/// Width of one label block. The arc's end points are placed at the centre
/// of these blocks, so the two must stay in sync.
const double _kLegendWidth = 100;

/// Draws the semicircular progress arc: track + gold fill + a glowing
/// knob riding the fill's leading edge. Path runs from the *right*
/// edge (current prayer, matching RTL reading order) to the *left*
/// edge (next prayer) — see [progress]=0 → knob at the right.
class _ArcPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Each endpoint sits above a prayer label — horizontally on the label's
    // mid-point, with [_kLegendGap] of air before the text starts — so the
    // arc reads as running from the current prayer on the right to the next
    // one on the left. Keep [_kLegendHeight] in sync with _legend.
    final r = size.width / 2 - _kLegendWidth / 2;
    final center = Offset(size.width / 2, size.height - _kLegendHeight - _kLegendGap);
    final rect = Rect.fromCircle(center: center, radius: r);

    // Upper semicircle only: angle 0 is the right end (current prayer) and a
    // negative sweep travels up and over to the left end (next prayer).
    const startAngle = 0.0;
    final sweep = -math.pi * progress;

    // 1. Track — the unfilled remainder of the window.
    canvas.drawArc(
      rect,
      startAngle,
      -math.pi,
      false,
      Paint()
        ..color = color.withOpacity(.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // 2+3. The elapsed part of the window, drawn as a ribbon that starts
    // hairline-thin at the current prayer and thickens towards the leading
    // edge. It has to be a filled path, not a stroke: a stroke's width is
    // one number for the whole call, so there is no way to taper it.
    if (progress > 0.01) {
      final ribbon = _taperedArc(center, r, startAngle, sweep, 1.5, 7);

      // Glow first, underneath — the gold reads as lit rather than drawn on.
      canvas.drawPath(
        ribbon,
        Paint()
          ..color = AppColors.gold.withOpacity(.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Then the ribbon itself, brightening as it travels.
      canvas.drawPath(
        ribbon,
        Paint()
          ..shader = SweepGradient(
            center: Alignment.center,
            startAngle: math.pi,
            endAngle: 2 * math.pi,
            colors: [const Color(0xFFF0D089), AppColors.gold, const Color(0xFF9A6E22)],
            stops: const [0.0, 0.55, 1.0],
            transform: GradientRotation(math.pi),
          ).createShader(rect),
      );
    }

    // 4. End caps: a small tick at each end anchors the arc to its label.
    for (final angle in [0.0, -math.pi]) {
      final p = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      canvas.drawCircle(p, 3, Paint()..color = color.withOpacity(.35));
    }

    // 5. Knob riding the fill's leading edge: halo, disc, ring.
    final angle = startAngle + sweep;
    final knob = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
    canvas.drawCircle(
      knob,
      15,
      Paint()
        ..color = AppColors.gold.withOpacity(.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(knob, 8, Paint()..color = AppColors.gold);
    canvas.drawCircle(knob, 3.5, Paint()..color = Colors.white.withOpacity(.95));
  }

  /// The arc from [start] sweeping [sweep], as a closed ribbon whose width
  /// grows from [fromWidth] to [toWidth] along its length. Sampled rather
  /// than drawn with an arc primitive, because only a filled path can vary
  /// in thickness.
  Path _taperedArc(Offset center, double radius, double start, double sweep,
      double fromWidth, double toWidth) {
    const steps = 72;
    final outer = <Offset>[];
    final inner = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = start + sweep * t;
      final half = lerpDouble(fromWidth, toWidth, t)! / 2;
      final dx = math.cos(angle), dy = math.sin(angle);
      outer.add(Offset(center.dx + (radius + half) * dx, center.dy + (radius + half) * dy));
      inner.add(Offset(center.dx + (radius - half) * dx, center.dy + (radius - half) * dy));
    }
    final path = Path()..moveTo(outer.first.dx, outer.first.dy);
    for (final p in outer.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in inner.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.progress != progress || old.color != color;
}
