import 'dart:math' as math;

import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 300x400 card at (0, 0).
const _quad = <Offset>[
  Offset(0, 0),
  Offset(300, 0),
  Offset(300, 400),
  Offset(0, 400),
];

GenieMesh mesh(
  double g, {
  Offset target = const Offset(150, 700),
  Size targetSize = const Size(60, 60),
  double lag = 0.45,
  List<Offset> quad = _quad,
}) => SwipeGenie.mesh(
  quad: quad,
  target: target,
  targetSize: targetSize,
  progress: g,
  lag: lag,
);

double width(GenieMesh m, int slice) =>
    (m.positions[slice * 2 + 1] - m.positions[slice * 2]).distance;

Offset centre(GenieMesh m, int slice) =>
    (m.positions[slice * 2] + m.positions[slice * 2 + 1]) / 2;

void main() {
  test('at progress 0 the mesh is exactly the card', () {
    final m = mesh(0);
    // The first slice is the top edge, the last the bottom edge.
    expect(m.positions.first, _quad[0]);
    expect(m.positions[1], _quad[1]);
    expect(m.positions[m.positions.length - 2], _quad[3]);
    expect(m.positions.last, _quad[2]);
    // And every slice keeps the full width.
    for (var i = 0; i <= SwipeGenie.defaultSlices; i++) {
      expect(width(m, i), closeTo(300, 1e-9));
    }
  });

  test('at progress 1 everything has poured into the target', () {
    final m = mesh(1);
    for (var i = 0; i <= SwipeGenie.defaultSlices; i++) {
      expect((centre(m, i) - const Offset(150, 700)).distance, lessThan(1e-9));
      expect(width(m, i), closeTo(60, 1e-9)); // the width of the opening
    }
  });

  test('the near edge leads: it is closer to the target than the far edge', () {
    final m = mesh(0.4);
    final far = (centre(m, 0) - const Offset(150, 700)).distance;
    final near =
        (centre(m, SwipeGenie.defaultSlices) - const Offset(150, 700)).distance;
    expect(near, lessThan(far));
    // And the near slices are narrower: a funnel.
    expect(width(m, SwipeGenie.defaultSlices), lessThan(width(m, 0)));
  });

  test('the width narrows smoothly from far to near (a funnel, no steps)', () {
    final m = mesh(0.5);
    var worst = 0.0;
    for (var i = 1; i <= SwipeGenie.defaultSlices; i++) {
      worst = math.max(worst, (width(m, i) - width(m, i - 1)).abs());
    }
    expect(worst, lessThan(40)); // 300px wide card, 24 slices
  });

  test('progress is continuous: a small step moves the mesh a little', () {
    var previous = mesh(0);
    var worst = 0.0;
    for (var g = 0.01; g <= 1.0001; g += 0.01) {
      final now = mesh(g);
      for (var i = 0; i < now.positions.length; i++) {
        worst = math.max(
          worst,
          (now.positions[i] - previous.positions[i]).distance,
        );
      }
      previous = now;
    }
    expect(worst, lessThan(30)); // per 1% of progress, on a 700px journey
  });

  test('it also works toward the side, above, and for a tilted card', () {
    for (final target in <Offset>[
      const Offset(700, 200), // right
      const Offset(-400, 200), // left
      const Offset(150, -300), // above
    ]) {
      final start = mesh(0, target: target);
      final end = mesh(1, target: target);
      expect(start.positions.length, end.positions.length);
      for (var i = 0; i <= SwipeGenie.defaultSlices; i++) {
        expect((centre(end, i) - target).distance, lessThan(1e-9));
      }
    }
    // A card tilted by 20 degrees still starts exactly on its own corners.
    final c = const Offset(150, 200);
    final rot = 20 * math.pi / 180;
    Offset r(Offset p) {
      final d = p - c;
      return c +
          Offset(
            d.dx * math.cos(rot) - d.dy * math.sin(rot),
            d.dx * math.sin(rot) + d.dy * math.cos(rot),
          );
    }

    final tilted = <Offset>[for (final p in _quad) r(p)];
    final m = mesh(0, quad: tilted);
    expect((m.positions.first - tilted[0]).distance, lessThan(1e-9));
    expect((m.positions.last - tilted[2]).distance, lessThan(1e-9));
  });

  test('texture coordinates cover the whole card, top to bottom', () {
    final m = mesh(0.3);
    expect(m.uvs.first, const Offset(0, 0));
    expect(m.uvs[1], const Offset(1, 0));
    expect(m.uvs.last, const Offset(1, 1));
    expect(m.uvs, hasLength(m.positions.length));
  });

  test('a target to the side cuts the card into vertical slices', () {
    final m = mesh(0.3, target: const Offset(700, 200));
    expect(m.uvs.first, const Offset(0, 0));
    expect(m.uvs[1], const Offset(0, 1)); // a column, not a row
    expect(m.uvs.last, const Offset(1, 1));
  });

  test('lag 0 moves the whole card together', () {
    final m = mesh(0.5, lag: 0);
    final w0 = width(m, 0);
    for (var i = 1; i <= SwipeGenie.defaultSlices; i++) {
      expect(width(m, i), closeTo(w0, 1e-9));
    }
  });

  test('it dissolves over the last part and is solid before that', () {
    expect(SwipeGenie.opacity(0), 1);
    expect(SwipeGenie.opacity(0.8), 1);
    expect(SwipeGenie.opacity(1), 0);
    var previous = 1.0;
    for (var g = 0.8; g <= 1; g += 0.01) {
      final o = SwipeGenie.opacity(g);
      expect(o, lessThanOrEqualTo(previous + 1e-9));
      previous = o;
    }
  });
}
