import 'package:flutter_test/flutter_test.dart';
import 'package:adhkar_app/widgets/ring_counter.dart';

/// The misbaha shows every dhikr as beads. Counts up to a full string are
/// drawn bead-for-bead; larger ones go round the same ring more than once,
/// the way a physical thirty-three-bead misbaha is used for a hundred. This
/// covers the lap arithmetic, which is silent when it is wrong — the ring
/// just looks slightly off.
void main() {
  int lit(int done, int beads, {bool finished = false}) =>
      RingCounter.litBeads(done: done, beads: beads, finished: finished);

  test('a fresh ring is empty and a short dhikr fills bead for bead', () {
    expect(lit(0, 3), 0);
    expect(lit(1, 3), 1);
    expect(lit(2, 3), 2);
    expect(lit(3, 3, finished: true), 3);
  });

  test('a single-count dhikr is one bead, lit once', () {
    expect(lit(0, 1), 0);
    expect(lit(1, 1, finished: true), 1);
  });

  test('completing a lap leaves the ring full, not blank', () {
    expect(lit(33, 33), 33);
    expect(lit(66, 33), 33);
  });

  test('the next tap after a lap starts the ring again at one', () {
    expect(lit(34, 33), 1);
    expect(lit(67, 33), 1);
  });

  test('a hundred on a ring of thirty-three ends full', () {
    expect(lit(99, 33), 33);
    // Without the finished flag the hundredth tap would show a single bead;
    // a completed dhikr must read as a completed ring.
    expect(lit(100, 33, finished: true), 33);
  });

  test('never lights more beads than the ring holds', () {
    for (var done = 0; done <= 200; done++) {
      final n = lit(done, 33);
      expect(n, inInclusiveRange(0, 33));
    }
  });
}
