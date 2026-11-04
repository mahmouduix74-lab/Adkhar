import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import '../utils/nav.dart';
import 'home_screen.dart';

/// The opening screen: the app's mark on a sky that already carries the
/// current hour's colour — the same gradient the home header will show a
/// second later, so arriving on the home screen feels like the same room.
///
/// The mark itself is the day's arc, mirrored from the header's so the two
/// are a pair rather than a repeat, with a bed of eight-point stars behind
/// it. It draws itself in, the name settles under it, and the screen hands
/// off to home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void initState() {
    super.initState();
    // Long enough for the arc to finish drawing, short enough not to be a
    // toll gate. The home screen is already built behind the fade.
    Future.delayed(const Duration(milliseconds: 1850), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(fadeThrough(const HomeScreen()));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sky = context.watch<AppState>().current;
    final name = context.watch<SettingsState>().strings.appName;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [sky.c1, sky.c2, sky.c3],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final draw = Curves.easeInOut.transform(_c.value);
              final text = Curves.easeOut
                  .transform(((_c.value - 0.55) / 0.45).clamp(0.0, 1.0));
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 168,
                    height: 168,
                    child: CustomPaint(
                      painter: _MarkPainter(progress: draw),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Opacity(
                    opacity: text,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - text)),
                      child: Text(
                        name,
                        style: uiFont(
                          size: 30,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ).copyWith(letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The mark: a bed of faint eight-point stars, then the day's arc — mirrored
/// against the header's, tapering thin to thick — with a light riding its
/// leading edge. [progress] draws the arc and the light in from nothing.
class _MarkPainter extends CustomPainter {
  final double progress;
  const _MarkPainter({required this.progress});

  static const _gold = Color(0xFFC2913A);
  static const _goldHi = Color(0xFFE8C47A);

  @override
  void paint(Canvas canvas, Size size) {
    _pattern(canvas, size);

    final cx = size.width / 2;
    final cy = size.height * 0.62;
    final radius = size.width * 0.40;

    // Mirrored: the header arc runs right-to-left, so this one runs
    // left-to-right — 350° back to 190°, thick end first.
    const a0 = 350.0, a1 = 190.0;
    const wThin = 2.0, wThick = 7.0;
    final sweepEnd = a0 + (a1 - a0) * progress;

    final path = Path();
    final outer = <Offset>[];
    final inner = <Offset>[];
    const steps = 96;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final ang = (a0 + (sweepEnd - a0) * t) * math.pi / 180;
      final half = (wThin + (wThick - wThin) * t) / 2;
      final c = math.cos(ang), s = math.sin(ang);
      outer.add(Offset(cx + (radius + half) * c, cy + (radius + half) * s));
      inner.add(Offset(cx + (radius - half) * c, cy + (radius - half) * s));
    }
    path.addPolygon([...outer, ...inner.reversed], true);
    canvas.drawPath(path, Paint()..color = _gold);

    // Rounded thin cap where the arc begins.
    final a0r = a0 * math.pi / 180;
    canvas.drawCircle(
      Offset(cx + radius * math.cos(a0r), cy + radius * math.sin(a0r)),
      wThin / 2,
      Paint()..color = _gold,
    );

    // The light on the leading edge.
    if (progress > 0.02) {
      final ar = sweepEnd * math.pi / 180;
      final p = Offset(cx + radius * math.cos(ar), cy + radius * math.sin(ar));
      canvas.drawCircle(
        p,
        16,
        Paint()
          ..color = _goldHi.withOpacity(.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(p, 6.5, Paint()..color = _goldHi);
      canvas.drawCircle(p, 3, Paint()..color = Colors.white);
    }
  }

  /// A faint tessellation of eight-point stars — the mark sits on it rather
  /// than floating on a flat wash.
  void _pattern(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(.05);
    const step = 34.0;
    for (var y = -step; y < size.height + step; y += step) {
      for (var x = -step; x < size.width + step; x += step) {
        _star(canvas, Offset(x, y), step * 0.34, paint);
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final rr = i.isEven ? r : r * 0.42;
      final a = i * math.pi / 8;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.progress != progress;
}
