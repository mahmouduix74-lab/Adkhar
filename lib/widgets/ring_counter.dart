import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import '../utils/arabic_numerals.dart';

/// The tasbih counter: a misbaha rendered as a ring of beads that turns by
/// exactly one bead on every tap.
///
/// The gesture a counter has to earn is the one made without looking, so the
/// feedback is layered: the ring rotates one seat with a spring, the bead
/// that just landed at the top swells and settles, a ripple leaves the
/// centre, the number springs, and the device taps back. All of it is driven
/// by one controller so the parts stay in step.
///
/// Every dhikr gets beads, whatever its count. A count of one is a ring with
/// a single bead that turns all the way round; a count of a hundred borrows
/// what a real misbaha does — the string holds [_ringBeads] beads and you go
/// round it more than once, so the ring shows the current lap while the
/// number in the middle keeps the true total. The faint track circle is
/// always drawn underneath, so the counter keeps its shape at any count.
class RingCounter extends StatefulWidget {
  final int remaining;
  final int total;
  final VoidCallback onTap;

  const RingCounter({
    super.key,
    required this.remaining,
    required this.total,
    required this.onTap,
  });

  /// How many beads are lit for [done] taps on a ring of [beads].
  ///
  /// Laps count from one rather than zero, so completing a lap leaves the
  /// ring full for the tap that follows instead of blanking it, and a
  /// finished dhikr always ends on a full ring however its total divides.
  /// Exposed for testing: the modulo is the part that goes wrong quietly.
  static int litBeads({
    required int done,
    required int beads,
    required bool finished,
  }) {
    if (beads <= 0 || done <= 0) return 0;
    if (finished) return beads;
    return ((done - 1) % beads) + 1;
  }

  @override
  State<RingCounter> createState() => _RingCounterState();
}

class _RingCounterState extends State<RingCounter> with SingleTickerProviderStateMixin {
  /// A physical misbaha is a string of thirty-three. Counts above it are
  /// counted in laps of the same ring rather than by crowding more beads on,
  /// which is both what the object does and the point past which dots stop
  /// being countable and turn into texture.
  static const int _ringBeads = 33;
  static const double _size = 168;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  /// Advances by one on every counted tap. The ring's rotation is read from
  /// this rather than from the remaining count, so the beads keep turning
  /// the same way even on the last tap, when remaining stops changing.
  int _turns = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.remaining <= 0) return;
    final settings = context.read<SettingsState>();

    // Fired before the callback so the feedback lands on the touch, not
    // after the rebuild it triggers.
    if (settings.haptics) {
      widget.remaining == 1
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.selectionClick();
    }
    if (settings.sound) SystemSound.play(SystemSoundType.click);

    setState(() => _turns++);
    _c.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.total;
    final done = total - widget.remaining;
    final beads = total <= 0 ? 0 : math.min(total, _ringBeads);
    final progress = total == 0 ? 0.0 : done / total;
    final finished = widget.remaining <= 0;

    final lit = RingCounter.litBeads(done: done, beads: beads, finished: finished);

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // One eased step per tap, so the ring settles on a bead rather
          // than drifting continuously.
          final step = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
          return SizedBox(
            width: _size,
            height: _size,
            child: CustomPaint(
              painter: _MisbahaPainter(
                beads: beads,
                done: lit,
                progress: progress,
                turns: _turns,
                step: step,
                pulse: Curves.easeOut.transform(t),
                trackColor: AppColors.line,
                beadColor: AppColors.gold,
                idleBeadColor: AppColors.ink3.withOpacity(.35),
                finished: finished,
              ),
              child: Center(child: _readout(done, total, finished, t)),
            ),
          );
        },
      ),
    );
  }

  Widget _readout(int done, int total, bool finished, double t) {
    // A short spring on the number itself: it dips on the tap and comes
    // back, which reads as the count being "struck" rather than replaced.
    final scale = 1 + 0.12 * math.sin(math.pi * Curves.easeOut.transform(t));
    return Transform.scale(
      scale: finished ? 1 : scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            finished ? '✓' : ar(widget.remaining),
            style: uiFont(
              size: finished ? 44 : 46,
              weight: FontWeight.w700,
              color: finished ? AppColors.green : AppColors.ink,
            ).copyWith(height: 1),
          ),
          const SizedBox(height: 4),
          fractionText(done, total, size: 13, color: AppColors.ink3),
        ],
      ),
    );
  }
}

class _MisbahaPainter extends CustomPainter {
  final int beads;
  final int done;
  final double progress;
  final int turns;
  final double step;
  final double pulse;
  final Color trackColor;
  final Color beadColor;
  final Color idleBeadColor;
  final bool finished;

  const _MisbahaPainter({
    required this.beads,
    required this.done,
    required this.progress,
    required this.turns,
    required this.step,
    required this.pulse,
    required this.trackColor,
    required this.beadColor,
    required this.idleBeadColor,
    required this.finished,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    _ripple(canvas, center, radius);

    // The track is always there: without it a low-count dhikr showed a lone
    // dot floating in space, which looked like something had failed to load.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = beads == 0 ? 7 : 1.4
        ..color = trackColor,
    );

    if (beads == 0) {
      _arc(canvas, center, radius);
      return;
    }

    // The ring sits one seat back and rotates forward through the tap, so a
    // bead travels into the top slot instead of appearing there.
    final seat = 2 * math.pi / beads;
    final rotation = -math.pi / 2 + seat * (turns - 1 + step);

    // Beads are sized to the gap between seats so a full string of thirty-
    // three still reads as separate beads, and capped so a ring of three
    // does not turn into three saucers.
    final gap = 2 * math.pi * radius / beads;
    final beadRadius = math.min(5.4, gap * 0.36);
    // The swell has to stay inside its own seat for the same reason.
    final maxSwell = beadRadius <= 5.4 * 0.999 ? 1.6 : 2.1;

    for (var i = 0; i < beads; i++) {
      final angle = rotation + seat * i;
      final at = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final counted = i < done;

      // The bead now arriving at the top is the one just counted; it swells
      // and settles rather than snapping to its new colour.
      final isLanding = counted && i == done - 1;
      final swell =
          isLanding ? 1 + (maxSwell - 1) * math.sin(math.pi * step) : 1.0;

      // Beads still to come are drawn from the ink, not from the track
      // colour: at track colour they vanished into the ring they sit on, and
      // a misbaha only reads as one when the beads ahead are visible too.
      canvas.drawCircle(
        at,
        (counted ? beadRadius : beadRadius * 0.7) * swell,
        Paint()..color = counted ? beadColor : idleBeadColor,
      );
      if (isLanding) {
        canvas.drawCircle(
          at,
          beadRadius * 1.7 * swell,
          Paint()
            ..color = beadColor.withOpacity(.28 * (1 - step).clamp(0.0, 1.0))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }
  }

  /// A single ring leaving the centre on each tap. It reads as the tap
  /// registering even when the beads are too small to watch.
  void _ripple(Canvas canvas, Offset center, double radius) {
    if (pulse <= 0 || pulse >= 1) return;
    canvas.drawCircle(
      center,
      radius * (0.35 + 0.75 * pulse),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = beadColor.withOpacity(.35 * (1 - pulse)),
    );
  }

  /// Counts outside the bead range get a plain arc on the same track — a
  /// ring of a hundred beads is unreadable, and a ring of one is not a ring.
  void _arc(Canvas canvas, Offset center, double radius) {
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = beadColor,
    );
  }

  @override
  bool shouldRepaint(covariant _MisbahaPainter old) =>
      old.done != done ||
      old.turns != turns ||
      old.step != step ||
      old.pulse != pulse ||
      old.progress != progress ||
      old.finished != finished ||
      old.beadColor != beadColor ||
      old.idleBeadColor != idleBeadColor ||
      old.trackColor != trackColor;
}
