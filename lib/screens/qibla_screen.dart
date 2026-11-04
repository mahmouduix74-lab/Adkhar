import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/compass.dart';
import '../data/qibla.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import '../utils/arabic_numerals.dart';

/// Finding the qibla without a compass rose.
///
/// Every qibla app draws the same thing: a dial with N/E/S/W and a needle
/// you have to read. Reading a dial is a second task on top of the first
/// one, and the number it gives you — "137° from north" — is not a number
/// you can act on unless you already know which way north is.
///
/// So this shows the one thing you can act on: how far to turn, and which
/// way. A horizon line runs across the screen with a fixed mark at its
/// centre — that is where you are facing. A point of light sits on the line
/// where the Kaaba is, and slides toward the centre as you turn. Standing
/// on that point is a column of light: faint while you are turned away,
/// brightening and widening as you come round, and burning straight up in
/// front of you when you are there.
///
/// Nothing to read, nothing to interpret. Turn until the light is in front
/// of you.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  /// Within this many degrees the beam locks and the phone taps once. Three
  /// degrees is finer than anyone can hold a phone, and far finer than the
  /// disagreement between qibla methods, so it is a confident "yes" rather
  /// than a hair trigger.
  static const double _lockDegrees = 3;

  /// The half-width of the horizon in degrees: the Kaaba at 90° off is at
  /// the edge of the screen, which puts the useful range — the last quarter
  /// turn — across the full width instead of squeezing all 360° into it.
  static const double _span = 90;

  StreamSubscription<double>? _sub;
  double? _heading;
  bool _compassChecked = false;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    _sub = DeviceCompass.heading.listen(
      (degrees) {
        if (!mounted) return;
        setState(() {
          _heading = degrees;
          _compassChecked = true;
        });
        _announceIfAligned(degrees);
      },
      onDone: () {
        if (mounted) setState(() => _compassChecked = true);
      },
      onError: (_) {
        if (mounted) setState(() => _compassChecked = true);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Degrees to turn, signed: positive means the Kaaba is to your right.
  static double _signedOffset(double bearing, double heading) {
    final raw = (bearing - heading) % 360;
    return raw > 180 ? raw - 360 : raw;
  }

  /// Sounds and buzzes once, on the reading that crosses into the qibla.
  ///
  /// Driven by the compass reading rather than by build: build runs for all
  /// sorts of reasons that have nothing to do with turning — a rebuild from
  /// the settings, a theme change — and firing feedback from there means
  /// the phone can buzz at you while you are standing perfectly still.
  ///
  /// Both halves are the user's to switch off, in the same two settings
  /// that govern the tasbih counter.
  void _announceIfAligned(double heading) {
    final here = context.read<AppState>().coordinates;
    final bearing = Qibla.bearingFrom(here.latitude, here.longitude);
    final aligned = _signedOffset(bearing, heading).abs() <= _lockDegrees;

    if (aligned == _wasAligned) return;
    _wasAligned = aligned;
    if (!aligned) return;

    final settings = context.read<SettingsState>();
    // Heavier than the counter's tick: this one says "stop here", and it
    // has to land through a pocket or an outstretched arm.
    if (settings.haptics) HapticFeedback.heavyImpact();
    if (settings.sound) SystemSound.play(SystemSoundType.click);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final strings = context.watch<SettingsState>().strings;
    final here = app.coordinates;

    final bearing = Qibla.bearingFrom(here.latitude, here.longitude);
    final distance = Qibla.distanceKmFrom(here.latitude, here.longitude);
    final live = _heading != null;
    final offset = _signedOffset(bearing, _heading ?? 0);
    final aligned = live && offset.abs() <= _lockDegrees;

    // White rather than the app's grey paper: the black cube and its label
    // are the only solid things on this screen and they want clean ground.
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(strings.qibla, style: pageTitle()),
      ),
      body: SafeArea(
        top: false,
        // One tween drives the marker, the beam and the glow together, so
        // they cannot arrive at different times and come apart.
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: offset),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          builder: (context, shown, _) {
            final closeness = (1 - shown.abs() / 45).clamp(0.0, 1.0);
            return Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => CustomPaint(
                      size: Size(box.maxWidth, box.maxHeight),
                      painter: _HorizonPainter(
                        offset: shown,
                        span: _span,
                        closeness: closeness,
                        live: live,
                        beam: AppColors.gold,
                        line: AppColors.ink3,
                        ink: AppColors.ink,
                        background: AppColors.surface,
                        label: strings.kaabaLabel,
                        labelStyle: uiFont(size: 13, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                _readout(strings, offset, aligned, live),
                const SizedBox(height: 22),
                _footnotes(strings, bearing, distance, live, app.usingDeviceLocation),
                const SizedBox(height: 22),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The number you act on is how far to turn — not the bearing from north,
  /// which is only useful to someone who already knows where north is.
  ///
  /// Unless the device cannot tell which way it is pointing, in which case
  /// there is no turn to give and the bearing is the honest thing to show:
  /// the centre of the horizon is then north, not where you are facing.
  Widget _readout(AppStrings strings, double offset, bool aligned, bool live) {
    if (!live) {
      return Column(
        children: [
          Text('${ar(offset.abs().round())}°',
              style: uiFont(size: 52, weight: FontWeight.w300, color: AppColors.ink)
                  .copyWith(height: 1, letterSpacing: -1)),
          const SizedBox(height: 8),
          Text(strings.fromNorth,
              style: uiFont(size: 17, weight: FontWeight.w500, color: AppColors.ink3)),
        ],
      );
    }
    if (aligned) {
      return Column(
        children: [
          Icon(LucideIcons.check, size: 30, color: AppColors.gold),
          const SizedBox(height: 10),
          Text(strings.qiblaAligned,
              style: uiFont(size: 20, weight: FontWeight.w700, color: AppColors.gold)),
        ],
      );
    }

    final away = offset.abs();
    final instruction = away > 150
        ? strings.turnAround
        : offset > 0
            ? strings.turnRight
            : strings.turnLeft;

    return Column(
      children: [
        Text('${ar(away.round())}°',
            style: uiFont(size: 52, weight: FontWeight.w300, color: AppColors.ink)
                .copyWith(height: 1, letterSpacing: -1)),
        const SizedBox(height: 8),
        Text(instruction,
            style: uiFont(size: 17, weight: FontWeight.w500, color: AppColors.ink3)),
      ],
    );
  }

  Widget _footnotes(AppStrings strings, double bearing, double distance,
      bool live, bool locatedByDevice) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            live
                ? '${ar(bearing.round())}° ${strings.fromNorth}'
                    '   ·   ${ar(distance.round())} ${strings.kmToMecca}'
                : '${ar(distance.round())} ${strings.kmToMecca}',
            textAlign: TextAlign.center,
            style: uiFont(size: 14, color: AppColors.ink3),
          ),
          if (!locatedByDevice) ...[
            const SizedBox(height: 10),
            _warning(LucideIcons.triangleAlert, strings.approximateLocation),
          ],
          if (!live && _compassChecked) ...[
            const SizedBox(height: 10),
            _warning(LucideIcons.compass, strings.noCompass),
          ],
        ],
      ),
    );
  }

  Widget _warning(IconData icon, String text) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: AppColors.ink3.withOpacity(.7)),
          const SizedBox(width: 7),
          Flexible(
            child: Text(text,
                textAlign: TextAlign.center,
                style: uiFont(size: 13, color: AppColors.ink3.withOpacity(.7))),
          ),
        ],
      );
}

/// The horizon, the mark for where you are facing, and the beam standing on
/// the Kaaba.
class _HorizonPainter extends CustomPainter {
  /// How far below the Kaaba's centre its whole block — cube plus label —
  /// finishes. The beam starts here, so it cannot creep up into the word.
  static const double _kaabaBlock = 62;

  final double offset;
  final double span;
  final double closeness;
  final bool live;
  final Color beam;
  final Color line;
  final Color ink;
  final Color background;
  final String label;
  final TextStyle labelStyle;

  const _HorizonPainter({
    required this.offset,
    required this.span,
    required this.closeness,
    required this.live,
    required this.beam,
    required this.line,
    required this.ink,
    required this.background,
    required this.label,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The horizon sits low in its box so the beam has the whole space above
    // it to rise into. That empty space is the point: it is what the light
    // needs in order to look like light.
    final y = size.height * 0.86;
    final half = size.width / 2;
    // Wide enough that the Kaaba, not just the marker dot, still clears the
    // screen edge when the whole thing is parked at full deflection.
    final inset = 34.0;
    final reach = half - inset;

    final fraction = (offset / span).clamp(-1.0, 1.0);
    final markerX = half + fraction * reach;

    // The Kaaba does not move. It is the target, fixed above the centre —
    // above the mark for where you are facing — so the whole instruction is
    // "bring the light up to it". A Kaaba that slid along with the beam was
    // decoration; a fixed one is the thing you are aiming at.
    final kaabaY = size.height * 0.13;

    _ambient(canvas, size, markerX, y);
    _beam(canvas, size, markerX, y, kaabaY);
    _ticks(canvas, size, y, half, reach);
    _horizon(canvas, size, y);
    _marker(canvas, markerX, y);
    _youAreHere(canvas, half, y);
    _kaaba(canvas, half, kaabaY);
  }

  /// A wash of colour behind the beam. On its own the beam is a hard shape;
  /// the wash is what makes the screen feel lit rather than drawn on.
  void _ambient(Canvas canvas, Size size, double x, double y) {
    if (closeness <= 0.01) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(x, y),
          size.height * .8,
          [beam.withOpacity(.16 * closeness), beam.withOpacity(0)],
          [0, 1],
        )
        ..isAntiAlias = true,
    );
  }

  void _beam(Canvas canvas, Size size, double x, double y, double kaabaY) {
    final width = ui.lerpDouble(4, 14, closeness)!;
    // Starts below the Kaaba's label and runs down to you. Only the beam's
    // weight and brightness answer to how close you are; one that also got
    // shorter read as broken.
    final top = kaabaY + _kaabaBlock;
    final opacity = ui.lerpDouble(.22, .95, closeness)!;

    // The gradient thins toward the top but never reaches nothing: fading
    // to zero left a gap between the beam and the Kaaba, which read as the
    // light failing to arrive rather than as light.
    ui.Shader shade() => ui.Gradient.linear(
          Offset(x, y),
          Offset(x, top),
          [beam.withOpacity(opacity), beam.withOpacity(opacity * .55)],
        );

    canvas.drawRect(
      Rect.fromLTRB(x - width / 2, top, x + width / 2, y),
      Paint()
        ..shader = shade()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 10 * closeness),
    );
    // A harder core inside the glow, so the beam has an edge to read
    // against at a glance instead of being a smudge.
    canvas.drawRect(
      Rect.fromLTRB(x - 1, top, x + 1, y),
      Paint()..shader = shade(),
    );
  }

  /// The Kaaba: a solid, generously rounded black cube.
  ///
  /// Drawn as a filled shape rather than a thin outline. An outline of a
  /// cube is a diagram; filled and rounded it is an object, which is what
  /// makes it read warmly at this size. The kiswa's band and the door are
  /// cut out of it in the background colour rather than drawn on top, so
  /// the whole icon is one silhouette and stays legible when it is small.
  ///
  /// It stays black at every distance — the halo behind it is what warms as
  /// you come round, so the target keeps telling you how close you are
  /// without the icon itself changing colour.
  void _kaaba(Canvas canvas, double cx, double cy) {
    // A shade taller than it is wide, the way the building is.
    const w = 40.0;
    const h = 43.0;
    const r = Radius.circular(11);

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
      r,
    );
    final rect = body.outerRect;

    if (closeness > 0.01) {
      canvas.drawCircle(
        Offset(cx, cy),
        30,
        Paint()
          ..color = beam.withOpacity(.32 * closeness)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Always solid, never dimmed. Fading it was a way of saying "no
    // compass", but that is what the beam and the note below already say,
    // and a grey Kaaba just looks like a mistake.
    canvas.drawRRect(body, Paint()..color = ink);

    // Everything below is cut back out in the page colour.
    canvas.save();
    canvas.clipRRect(body);
    final cut = Paint()..color = background;

    // The kiswa's band, sitting above centre the way it does on the cloth.
    canvas.drawRect(
      Rect.fromLTRB(rect.left, rect.top + h * .29, rect.right, rect.top + h * .35),
      cut,
    );

    // The door: right of centre, standing on the ground, softly rounded.
    final door = Rect.fromLTWH(
      rect.left + w * .57,
      rect.bottom - h * .27,
      w * .16,
      h * .27,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(door,
          topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
      cut,
    );
    canvas.restore();

    _label(canvas, cx, rect.bottom + 14);
  }

  /// The word under the icon. Painted here rather than stacked as a widget
  /// so it stays fixed to the cube wherever the cube is placed.
  void _label(Canvas canvas, double cx, double top) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: labelStyle.copyWith(color: ink),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, top));
  }

  /// Faint marks every fifteen degrees. They give the slide a scale without
  /// turning the screen back into a dial — there is nothing to read here,
  /// they are only there so the movement has texture.
  void _ticks(Canvas canvas, Size size, double y, double half, double reach) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var deg = 15; deg <= span; deg += 15) {
      for (final sign in const [-1, 1]) {
        final x = half + sign * (deg / span) * reach;
        final fade = 1 - (deg / span) * .75;
        paint
          ..color = line.withOpacity(.26 * fade)
          ..strokeWidth = 1.6;
        canvas.drawLine(Offset(x, y - 6), Offset(x, y + 6), paint);
      }
    }
  }

  /// The horizon itself, fading out at both ends so it reads as continuing
  /// past the screen rather than as a bar someone drew.
  void _horizon(Canvas canvas, Size size, double y) {
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..strokeWidth = 2.2
        ..shader = ui.Gradient.linear(
          Offset(0, y),
          Offset(size.width, y),
          [
            line.withOpacity(0),
            line.withOpacity(.5),
            line.withOpacity(.5),
            line.withOpacity(0),
          ],
          [0, .18, .82, 1],
        ),
    );
  }

  void _marker(Canvas canvas, double x, double y) {
    final r = ui.lerpDouble(5, 7.5, closeness)!;
    canvas.drawCircle(
      Offset(x, y),
      r + 6,
      Paint()
        ..color = beam.withOpacity(.30 * closeness)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()..color = live ? beam : beam.withOpacity(.5),
    );
  }

  /// Where you are facing: a small notch under the centre of the horizon,
  /// fixed. The marker moves, this never does — that is what makes "bring
  /// them together" the whole instruction.
  void _youAreHere(Canvas canvas, double x, double y) {
    final path = Path()
      ..moveTo(x, y + 7)
      ..lineTo(x - 6, y + 17)
      ..lineTo(x + 6, y + 17)
      ..close();
    canvas.drawPath(path, Paint()..color = line.withOpacity(.5));
  }

  @override
  bool shouldRepaint(covariant _HorizonPainter old) =>
      old.offset != offset ||
      old.closeness != closeness ||
      old.live != live ||
      old.beam != beam ||
      old.line != line ||
      old.ink != ink ||
      old.background != background ||
      old.label != label;
}
