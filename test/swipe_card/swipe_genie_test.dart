import 'dart:math' as math;
import 'dart:typed_data';

import 'package:craft_kit/craft_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 300x400 card at (0, 0): top left, top right, bottom right, bottom left.
const _quad = <Offset>[
  Offset(0, 0),
  Offset(300, 0),
  Offset(300, 400),
  Offset(0, 400),
];

final int _n = SwipeGenie.defaultResolution;

Float32List mesh(
  double g, {
  Offset target = const Offset(150, 700),
  double lag = 0.45,
  List<Offset> quad = _quad,
}) => SwipeGenie.positions(quad: quad, target: target, progress: g, lag: lag);

Offset vertex(Float32List m, int row, int col) {
  final i = (row * (_n + 1) + col) * 2;
  return Offset(m[i], m[i + 1]);
}

Offset bilinear(List<Offset> quad, double u, double v) =>
    Offset.lerp(
      Offset.lerp(quad[0], quad[1], u)!,
      Offset.lerp(quad[3], quad[2], u)!,
      v,
    )!;

Offset rotate(Offset p, double radians, Offset about) {
  final d = p - about;
  return about +
      Offset(
        d.dx * math.cos(radians) - d.dy * math.sin(radians),
        d.dx * math.sin(radians) + d.dy * math.cos(radians),
      );
}

void main() {
  group('topology', () {
    final t = SwipeGenie.topology();

    test('is a grid connected as triangles, covering the whole picture', () {
      expect(t.vertexCount, (_n + 1) * (_n + 1));
      expect(t.uvs.length, t.vertexCount * 2);
      expect(t.indices.length, _n * _n * 6);
      // uv runs from the picture's top left to its bottom right.
      expect(t.uvs.sublist(0, 2), [0, 0]);
      expect(t.uvs.sublist(t.uvs.length - 2), [1, 1]);
      // Every index points at a real vertex.
      expect(t.indices.every((i) => i < t.vertexCount), isTrue);
    });

    test('is built once and reused', () {
      expect(identical(SwipeGenie.topology(), t), isTrue);
    });

    test('stays within what a 16-bit index can address', () {
      expect(t.vertexCount, lessThan(65536));
    });
  });

  group('the mesh', () {
    test('at progress 0 is exactly the card', () {
      final m = mesh(0);
      for (var r = 0; r <= _n; r += 7) {
        for (var c = 0; c <= _n; c += 7) {
          final want = bilinear(_quad, c / _n, r / _n);
          expect((vertex(m, r, c) - want).distance, lessThan(1e-3));
        }
      }
    });

    test('at progress 1 the whole card is one point: the target', () {
      for (final target in <Offset>[
        const Offset(150, 700), // below
        const Offset(150, -300), // above
        const Offset(700, 200), // right
        const Offset(-400, 200), // left
        const Offset(650, 720), // diagonal, like the heart button
        const Offset(-300, -250), // the opposite diagonal
      ]) {
        final m = mesh(1, target: target);
        for (var i = 0; i < m.length; i += 2) {
          expect(
            (Offset(m[i], m[i + 1]) - target).distance,
            lessThan(1e-3),
            reason: 'toward $target',
          );
        }
      }
    });

    test('does not depend on which way is up or which corner is nearest', () {
      // Rotating the whole scene (the card and the target) by any angle must
      // rotate the result by exactly that angle. The old approach cut the card
      // along the screen's vertical or horizontal, so a diagonal target
      // sheared it and "ate" the nearest corner instead.
      const pivot = Offset(150, 200);
      const target = Offset(650, 720);
      for (final degrees in <double>[15, 37, 90, 133, 200, 291]) {
        final a = degrees * math.pi / 180;
        final quad = <Offset>[for (final p in _quad) rotate(p, a, pivot)];
        final rotatedTarget = rotate(target, a, pivot);
        for (final g in <double>[0.2, 0.5, 0.8]) {
          final plain = mesh(g, target: target);
          final turned = mesh(g, target: rotatedTarget, quad: quad);
          for (var i = 0; i < plain.length; i += 42) {
            final expected = rotate(Offset(plain[i], plain[i + 1]), a, pivot);
            expect(
              (Offset(turned[i], turned[i + 1]) - expected).distance,
              lessThan(0.01),
              reason: '$degrees degrees at $g',
            );
          }
        }
      }
    });

    test(
      'is mirror-symmetric when the target is on the card\'s centreline',
      () {
        final m = mesh(0.5);
        for (var r = 0; r <= _n; r += 3) {
          for (var c = 0; c <= _n; c += 3) {
            final a = vertex(m, r, c);
            final b = vertex(m, r, _n - c);
            expect(a.dy, closeTo(b.dy, 1e-3));
            expect(a.dx + b.dx, closeTo(300, 1e-2)); // mirrored about x = 150
          }
        }
      },
    );

    test('no vertex crosses the axis, and each squeezes in as it goes', () {
      const target = Offset(650, 720);
      final center = _quad.reduce((a, b) => a + b) / 4;
      final axis = (target - center) / (target - center).distance;
      final side = Offset(-axis.dy, axis.dx);
      double lateral(Offset p) =>
          (p - center).dx * side.dx + (p - center).dy * side.dy;

      var previous = mesh(0, target: target);
      for (var g = 0.05; g <= 1.0001; g += 0.05) {
        final now = mesh(g, target: target);
        for (var i = 0; i < now.length; i += 2) {
          final before = lateral(Offset(previous[i], previous[i + 1]));
          final after = lateral(Offset(now[i], now[i + 1]));
          // Same side of the axis...
          expect(after * before, greaterThanOrEqualTo(-1e-2));
          // ...and never further from it.
          expect(after.abs(), lessThanOrEqualTo(before.abs() + 1e-3));
        }
        previous = now;
      }
    });

    test('the edge facing the target leads', () {
      final m = mesh(0.4); // target straight below
      const target = Offset(150, 700);
      final far = (vertex(m, 0, _n ~/ 2) - target).distance;
      final near = (vertex(m, _n, _n ~/ 2) - target).distance;
      expect(near, lessThan(far));
      // And it is narrower there: a funnel.
      final farWidth = (vertex(m, 0, _n) - vertex(m, 0, 0)).distance;
      final nearWidth = (vertex(m, _n, _n) - vertex(m, _n, 0)).distance;
      expect(nearWidth, lessThan(farWidth));
    });

    test(
      'the sides curve smoothly into the neck (no straight cut, no kink)',
      () {
        // Walk down the left edge of a card whose target is straight below.
        final m = mesh(0.55);
        final xs = <double>[for (var r = 0; r <= _n; r++) vertex(m, r, 0).dx];
        // Moving toward the centreline the whole way...
        for (var r = 1; r < xs.length; r++) {
          expect(xs[r], greaterThanOrEqualTo(xs[r - 1] - 1e-6));
        }
        // ...and curving: the slope changes gradually, without a corner.
        var worstBend = 0.0;
        for (var r = 1; r < xs.length - 1; r++) {
          worstBend = math.max(
            worstBend,
            (xs[r + 1] - 2 * xs[r] + xs[r - 1]).abs(),
          );
        }
        expect(worstBend, lessThan(12));
        // A straight cut would make every step equal; an S-curve does not.
        final first = xs[1] - xs[0];
        final middle = xs[_n ~/ 2 + 1] - xs[_n ~/ 2];
        expect((middle - first).abs(), greaterThan(0.2));
      },
    );

    test('nothing folds over itself on the way in', () {
      for (var g = 0.0; g <= 1.0001; g += 0.05) {
        final m = mesh(g); // target straight below, down the centre column
        var previousY = -double.infinity;
        for (var r = 0; r <= _n; r++) {
          final y = vertex(m, r, _n ~/ 2).dy;
          expect(y, greaterThanOrEqualTo(previousY - 1e-3), reason: 'at $g');
          previousY = y;
        }
      }
    });

    test(
      'progress is continuous: a small step moves every vertex a little',
      () {
        for (final target in <Offset>[
          const Offset(150, 700),
          const Offset(650, 720),
        ]) {
          var previous = mesh(0, target: target);
          var worst = 0.0;
          for (var g = 0.01; g <= 1.0001; g += 0.01) {
            final now = mesh(g, target: target);
            for (var i = 0; i < now.length; i += 2) {
              worst = math.max(
                worst,
                (Offset(now[i], now[i + 1]) -
                        Offset(previous[i], previous[i + 1]))
                    .distance,
              );
            }
            previous = now;
          }
          expect(worst, lessThan(30)); // per 1% of the way, on a 700px journey
        }
      },
    );

    test('a tilted, scaled card starts exactly on its own corners', () {
      const pivot = Offset(150, 200);
      final quad = <Offset>[
        for (final p in _quad) rotate(pivot + (p - pivot) * 0.8, 0.35, pivot),
      ];
      final m = mesh(0, quad: quad, target: const Offset(650, 720));
      expect((vertex(m, 0, 0) - quad[0]).distance, lessThan(1e-3));
      expect((vertex(m, 0, _n) - quad[1]).distance, lessThan(1e-3));
      expect((vertex(m, _n, _n) - quad[2]).distance, lessThan(1e-3));
      expect((vertex(m, _n, 0) - quad[3]).distance, lessThan(1e-3));
    });

    test('a target at the card\'s own centre does not break', () {
      final m = mesh(0.5, target: const Offset(150, 200));
      expect(m.every((v) => v.isFinite), isTrue);
    });

    test('lag 0 moves the whole card together', () {
      // Every vertex is at the same stage, so the centre row (which is on the
      // axis) ends up as far along as the corners are.
      final m = mesh(0.5, lag: 0);
      final top = vertex(m, 0, _n ~/ 2).dy;
      final bottom = vertex(m, _n, _n ~/ 2).dy;
      final together = mesh(0.5, lag: 0);
      expect(m, together);
      expect(bottom, greaterThan(top));
    });
  });

  test('the card dissolves over the last part and is solid before that', () {
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
