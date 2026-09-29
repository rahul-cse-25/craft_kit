import 'dart:math' as math;
import 'dart:ui' show Offset, Size, lerpDouble;

import 'package:flutter/animation.dart' show Curves;

/// A triangle-strip mesh: [positions] in stack coordinates and matching
/// texture coordinates [uvs] as fractions (0 to 1) of the captured card.
final class GenieMesh {
  /// Creates a mesh.
  const GenieMesh(this.positions, this.uvs);

  /// Vertices, two per slice.
  final List<Offset> positions;

  /// Texture coordinates for [positions], as fractions of the image.
  final List<Offset> uvs;
}

/// The "genie" warp: a card pours into a target like the macOS Dock minimize
/// effect, and (run backwards) pours back out of it.
///
/// The card is cut into thin slices across the direction of travel. The slice
/// nearest the target moves first and narrows to the target's width, and the
/// farther ones follow, so the sides of the card draw a smooth funnel.
///
/// This is pure geometry, so it is testable without any rendering.
abstract final class SwipeGenie {
  /// How many slices the card is cut into.
  static const int defaultSlices = 24;

  /// The mesh at [progress] (0 = the card as it was, 1 = fully in the target).
  ///
  /// [quad] holds the card's corners in stack coordinates, in the order top
  /// left, top right, bottom right, bottom left (already including any tilt or
  /// scale). [target] is where the card pours into and [targetSize] how wide
  /// the opening is.
  ///
  /// [lag] (0 to 1) is how far the far edge trails the near edge: 0 moves the
  /// whole card together, larger values make a longer funnel.
  static GenieMesh mesh({
    required List<Offset> quad,
    required Offset target,
    required Size targetSize,
    required double progress,
    double lag = 0.45,
    int slices = defaultSlices,
  }) {
    assert(quad.length == 4, 'quad needs four corners');
    assert(slices >= 1, 'slices must be positive');
    final tl = quad[0];
    final tr = quad[1];
    final br = quad[2];
    final bl = quad[3];
    final center = (tl + tr + br + bl) / 4;
    final toTarget = target - center;
    final vertical = toTarget.dy.abs() >= toTarget.dx.abs();

    // Each slice runs from a point on edge A to a point on edge B. For a
    // target above or below, slices are horizontal and travel along the
    // card's height; for one to a side, they are vertical.
    final Offset a0, a1, b0, b1;
    final bool nearAtEnd;
    final Offset goalDirection;
    final double goalHalf;
    if (vertical) {
      a0 = tl;
      a1 = bl;
      b0 = tr;
      b1 = br;
      nearAtEnd = toTarget.dy >= 0;
      goalDirection = const Offset(1, 0);
      goalHalf = math.max(6.0, targetSize.width / 2);
    } else {
      a0 = tl;
      a1 = tr;
      b0 = bl;
      b1 = br;
      nearAtEnd = toTarget.dx >= 0;
      goalDirection = const Offset(0, 1);
      goalHalf = math.max(6.0, targetSize.height / 2);
    }

    final g = progress.clamp(0.0, 1.0);
    final positions = <Offset>[];
    final uvs = <Offset>[];

    for (var i = 0; i <= slices; i++) {
      final f = i / slices;
      final a = Offset.lerp(a0, a1, f)!;
      final b = Offset.lerp(b0, b1, f)!;
      final c0 = Offset.lerp(a, b, 0.5)!;
      final half0 = (b - a) / 2;
      final length0 = half0.distance;
      final direction0 = length0 == 0 ? goalDirection : half0 / length0;

      // 1 at the edge nearest the target, 0 at the far edge.
      final near = nearAtEnd ? f : 1 - f;
      // Each slice waits for its turn: the near edge starts at once, the far
      // edge after `lag`, and all arrive together at progress 1.
      final q = (g * (1 + lag) - (1 - near) * lag).clamp(0.0, 1.0);
      final move = Curves.easeInOutSine.transform(q);
      final narrow = Curves.easeOutCubic.transform(q);

      final c = Offset.lerp(c0, target, move)!;
      var direction = Offset.lerp(direction0, goalDirection, q)!;
      final dl = direction.distance;
      direction = dl == 0 ? goalDirection : direction / dl;
      final half = lerpDouble(length0, goalHalf, narrow)!;

      positions
        ..add(c - direction * half)
        ..add(c + direction * half);
      if (vertical) {
        uvs
          ..add(Offset(0, f))
          ..add(Offset(1, f));
      } else {
        uvs
          ..add(Offset(f, 0))
          ..add(Offset(f, 1));
      }
    }
    return GenieMesh(positions, uvs);
  }

  /// How opaque the card is at [progress]: it fades over the last part, so it
  /// dissolves into the target instead of ending as a hard sliver.
  static double opacity(double progress) {
    final f = ((progress - 0.82) / 0.18).clamp(0.0, 1.0);
    return 1 - f * f * (3 - 2 * f);
  }
}
