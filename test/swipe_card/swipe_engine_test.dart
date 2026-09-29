import 'dart:math' as math;

import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';

const _card = Size(300, 400);
const _all = <SwipeDirection>{
  SwipeDirection.left,
  SwipeDirection.right,
  SwipeDirection.up,
  SwipeDirection.down,
};
const _horizontal = <SwipeDirection>{SwipeDirection.left, SwipeDirection.right};

SwipeDirection? decide(
  Offset offset, {
  Offset velocity = Offset.zero,
  Set<SwipeDirection> open = _all,
}) => SwipeMath.decide(
  offset: offset,
  velocity: velocity,
  cardSize: _card,
  open: open,
  threshold: 0.3,
  projectionTime: 0.18,
  minDistance: 8,
);

void main() {
  group('rubber band', () {
    test('follows the finger at first and never passes the limit', () {
      expect(SwipeMath.rubberBand(0, 36), 0);
      expect(SwipeMath.rubberBand(1, 36), closeTo(1, 0.05));
      var previous = 0.0;
      for (var x = 1.0; x <= 5000; x *= 1.5) {
        final y = SwipeMath.rubberBand(x, 36);
        expect(y, greaterThan(previous), reason: 'monotonic at $x');
        expect(y, lessThan(36));
        previous = y;
      }
    });

    test('un-stretching inverts stretching', () {
      for (final x in <double>[0, 3, 20, 100, 400, 2000]) {
        final stretched = SwipeMath.rubberBand(x, 36);
        expect(
          SwipeMath.unRubberBand(stretched, 36),
          closeTo(x, x * 1e-6 + 1e-6),
        );
      }
    });

    test('only directions without a behavior resist', () {
      const raw = Offset(200, -200);
      final out = SwipeMath.applyRubberBand(raw, _horizontal, 36);
      expect(out.dx, 200); // right is open: untouched
      expect(out.dy, lessThan(0));
      expect(out.dy, greaterThan(-36)); // up is closed: stretched
      final back = SwipeMath.removeRubberBand(out, _horizontal, 36);
      expect(back.dx, closeTo(200, 1e-6));
      expect(back.dy, closeTo(-200, 1e-3));
    });
  });

  group('progress', () {
    test(
      'is 0 for closed directions and measured against the commit distance',
      () {
        final p = SwipeMath.progress(
          offset: const Offset(45, 0),
          cardSize: _card,
          open: _horizontal,
          threshold: 0.3,
        );
        expect(p.right, closeTo(45 / 90, 1e-9));
        expect(p.left, 0);
        expect(p.up, 0);
        expect(p.dominant, SwipeDirection.right);

        final closed = SwipeMath.progress(
          offset: const Offset(0, -300),
          cardSize: _card,
          open: _horizontal,
          threshold: 0.3,
        );
        expect(closed.isActive, isFalse);
      },
    );

    test('is continuous across the diagonal (no flicker)', () {
      // Walk around a circle. With a "dominant direction" the overlay would
      // jump at 45 degrees; the per-direction values must move smoothly.
      SwipeProgress at(double degrees) {
        final r = degrees * math.pi / 180;
        return SwipeMath.progress(
          offset: Offset(math.cos(r), math.sin(r)) * 60,
          cardSize: _card,
          open: _all,
          threshold: 0.3,
        );
      }

      var worst = 0.0;
      var previous = at(0);
      for (var deg = 1.0; deg <= 360; deg++) {
        final now = at(deg);
        for (final d in SwipeDirection.values) {
          worst = math.max(worst, (now[d] - previous[d]).abs());
        }
        previous = now;
      }
      expect(worst, lessThan(0.05));
    });
  });

  group('release decision', () {
    test('a slow short drag springs back, a slow long one commits', () {
      expect(decide(const Offset(50, 0)), isNull);
      expect(decide(const Offset(100, 0)), SwipeDirection.right);
      expect(decide(const Offset(-100, 0)), SwipeDirection.left);
    });

    test('a quick flick commits after a short distance', () {
      expect(
        decide(const Offset(25, 0), velocity: const Offset(1500, 0)),
        SwipeDirection.right,
      );
      expect(
        decide(const Offset(0, -25), velocity: const Offset(0, -1500)),
        SwipeDirection.up,
      );
    });

    test('a tap or a nudge never commits, however fast', () {
      expect(decide(Offset.zero), isNull);
      expect(
        decide(const Offset(3, 0), velocity: const Offset(3000, 0)),
        isNull,
      );
    });

    test('pulling back cancels', () {
      // Dragged 110px right, then flicked back left.
      expect(
        decide(const Offset(110, 0), velocity: const Offset(-1200, 0)),
        isNull,
      );
    });

    test('a direction without a behavior never commits', () {
      expect(decide(const Offset(0, -300), open: _horizontal), isNull);
    });

    test('vertical directions are measured against the height', () {
      // 100px is past 30% of the width but not of the height (120px).
      expect(decide(const Offset(0, 100)), isNull);
      expect(decide(const Offset(0, 130)), SwipeDirection.down);
    });
  });

  group('geometry', () {
    final geometry = SwipeGeometry.forStack(
      const Size(300, 400),
      const EdgeInsets.only(bottom: 28),
    );

    test('the top card leaves the reserved strip free', () {
      expect(geometry.cardRect, const Rect.fromLTWH(0, 0, 300, 372));
    });

    test('exit targets are fully off the stack, and keep the drift', () {
      for (final d in SwipeDirection.values) {
        final target = geometry.exitTarget(d, Offset.zero, Offset.zero);
        expect(d.distance(target), geometry.exitDistance(d));
      }
      final left = geometry.exitTarget(
        SwipeDirection.left,
        const Offset(-50, 10),
        const Offset(-800, 400),
      );
      expect(left.dx, -geometry.exitDistance(SwipeDirection.left));
      expect(left.dy, greaterThan(10)); // carries on drifting down
    });
  });

  group('path', () {
    test('starts and ends where asked and bows upward', () {
      final path = SwipePath(
        from: Offset.zero,
        to: const Offset(-100, 300),
        arc: 0.2,
      );
      expect(path.at(0), Offset.zero);
      expect(path.at(1), const Offset(-100, 300));
      final straightMid = Offset.lerp(path.from, path.to, 0.5)!;
      expect(path.at(0.5).dy, lessThan(straightMid.dy));
    });

    test('a zero arc is a straight line', () {
      final path = SwipePath(
        from: Offset.zero,
        to: const Offset(80, 0),
        arc: 0,
      );
      expect(path.at(0.25).dy, 0);
      expect(path.at(0.25).dx, closeTo(20, 1e-9));
    });

    test('hands the release speed over only when heading the right way', () {
      final path = SwipePath(
        from: Offset.zero,
        to: const Offset(200, 0),
        arc: 0,
      );
      expect(path.progressVelocityFor(const Offset(400, 0)), greaterThan(0));
      expect(path.progressVelocityFor(const Offset(-400, 0)), 0);
    });
  });

  group('moves', () {
    SpringMove spring({
      Offset from = const Offset(100, 0),
      Offset velocity = Offset.zero,
      Offset to = Offset.zero,
      SwipeSpring config = const SwipeSpring(
        stiffness: 320,
        dampingRatio: 0.72,
      ),
      bool Function(Offset)? isOut,
    }) => SpringMove(
      from: from,
      velocity: velocity,
      to: to,
      spring: config.description,
      rotationFor: (o) => o.dx / 1000,
      isOut: isOut,
    );

    test(
      'starts exactly at the release position with the release velocity',
      () {
        final move = spring(
          from: const Offset(80, -20),
          velocity: const Offset(-600, 200),
        );
        expect(move.at(0).offset, const Offset(80, -20));
        expect(move.velocityAt(0).dx, closeTo(-600, 1e-6));
        expect(move.velocityAt(0).dy, closeTo(200, 1e-6));
        // One millisecond later the card has moved by about velocity * dt.
        final step = move.at(0.001).offset - move.at(0).offset;
        expect(step.dx, closeTo(-0.6, 0.05));
      },
    );

    test('a settling spring overshoots a little, then rests exactly', () {
      final move = spring();
      var minX = double.infinity;
      for (var t = 0.0; t < 1.5; t += 1 / 240) {
        minX = math.min(minX, move.at(t).offset.dx);
      }
      expect(minX, lessThan(0)); // springy
      expect(minX, greaterThan(-25)); // but not wild
      expect(move.isDone(3), isTrue);
      expect(move.finalPose.offset, Offset.zero);
    });

    test('is smooth: no frame moves the card more than its speed allows', () {
      final move = spring(velocity: const Offset(-1500, 0));
      var previous = move.at(0).offset;
      for (var t = 1 / 120; t < 1.5; t += 1 / 120) {
        final now = move.at(t).offset;
        expect((now - previous).distance, lessThan(1500 / 120 + 1));
        previous = now;
      }
    });

    test('is a pure function of time, so a late frame is still exact', () {
      // Nothing is integrated frame by frame: a dropped frame cannot leave
      // the card anywhere but where the closed-form solution puts it.
      final move = spring(velocity: const Offset(-900, 100));
      final direct = move.at(0.5);
      for (final t in <double>[0.9, 0.1, 0.5, 2.0, 0.25]) {
        move.at(t); // in any order, as often as we like
      }
      expect(move.at(0.5), direct);
      // A late frame at 120ms lands on the same curve as an on-time one.
      final onTime = <double>[1 / 60, 2 / 60].map((t) => move.at(t)).toList();
      final late = move.at(2 / 60);
      expect(late, onTime.last);
    });

    test('a leaving card finishes as soon as it is out', () {
      final move = spring(
        from: Offset.zero,
        velocity: const Offset(-2000, 0),
        to: const Offset(-500, 0),
        config: const SwipeSpring(stiffness: 140, dampingRatio: 0.9),
        isOut: (o) => o.dx <= -450,
      );
      var t = 0.0;
      while (!move.isDone(t)) {
        t += 1 / 120;
        expect(t, lessThan(2));
      }
      expect(move.at(t).offset.dx, lessThanOrEqualTo(-450));
    });

    test('an undone consumed card grows and fades in while it returns', () {
      final move = SpringMove(
        from: const Offset(-100, 300),
        velocity: Offset.zero,
        to: Offset.zero,
        spring:
            const SwipeSpring(stiffness: 240, dampingRatio: 0.8).description,
        rotationFor: (_) => 0,
        fromScale: 0.08,
        fromOpacity: 0,
      );
      expect(move.at(0).scale, closeTo(0.08, 1e-9));
      expect(move.at(0).opacity, 0);
      expect(move.at(3).scale, closeTo(1, 1e-6));
      expect(move.at(3).opacity, closeTo(1, 1e-6));
    });

    test('a path move shrinks and fades along a monotonic progress', () {
      final path = SwipePath(from: Offset.zero, to: const Offset(-120, 320));
      final move = PathMove(
        path: path,
        progressVelocity: 1.5,
        spring: const SwipeSpring(stiffness: 210).description,
        fromRotation: 0.2,
        endScale: 0.08,
        fade: true,
      );
      expect(move.at(0).offset, Offset.zero);
      expect(move.at(0).scale, 1);
      var previous = -1.0;
      for (var t = 0.0; t < 2; t += 1 / 120) {
        final p = move.progressAt(t);
        expect(p, greaterThanOrEqualTo(previous));
        expect(p, inInclusiveRange(0, 1));
        previous = p;
      }
      expect(move.isDone(3), isTrue);
      expect(move.finalPose.scale, 0.08);
      expect(move.finalPose.opacity, 0);
      expect(move.at(10).offset, const Offset(-120, 320));
    });

    test('the promotion remainder settles to zero without overshoot', () {
      final s = ScalarSpring(
        from: 1,
        velocity: 0,
        spring: const SwipeSpring(stiffness: 260).description,
      );
      for (var t = 0.0; t < 1; t += 1 / 120) {
        expect(s.value(t), greaterThanOrEqualTo(-1e-6));
      }
      expect(s.isDone(3), isTrue);
    });
  });

  test('physics presets are real springs', () {
    for (final p in <SwipePhysics>[
      SwipePhysics.smooth,
      SwipePhysics.snappy,
      SwipePhysics.bouncy,
    ]) {
      final SpringDescription d = p.settle.description;
      expect(d.stiffness, greaterThan(0));
      expect(d.damping, greaterThan(0));
    }
    expect(
      const SwipePhysics().copyWith(commitThreshold: 0.5).commitThreshold,
      0.5,
    );
  });
}
