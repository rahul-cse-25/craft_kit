import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show EdgeInsets;

import '../swipe_direction.dart';
import '../swipe_progress.dart';

/// Pure functions behind the feel of the stack. No widgets, no clocks, so each
/// one can be tested on its own.
abstract final class SwipeMath {
  /// Resistance for pulling toward a direction that cannot be swiped.
  ///
  /// It starts with slope 1 (the card follows the finger at first) and
  /// approaches [limit] asymptotically, so it feels like stretching a rubber
  /// band.
  static double rubberBand(double distance, double limit) {
    if (distance <= 0) return distance;
    return distance * limit / (distance + limit);
  }

  /// The inverse of [rubberBand]. Used to resume a drag from a card that is
  /// currently stretched, without a jump.
  static double unRubberBand(double stretched, double limit) {
    if (stretched <= 0) return stretched;
    final s = math.min(stretched, limit * 0.999);
    return s * limit / (limit - s);
  }

  /// Applies [rubberBand] to the parts of [raw] that point toward a direction
  /// not in [open].
  static Offset applyRubberBand(
    Offset raw,
    Set<SwipeDirection> open,
    double limit,
  ) {
    double axis(double v, SwipeDirection positive, SwipeDirection negative) {
      if (v > 0 && !open.contains(positive)) return rubberBand(v, limit);
      if (v < 0 && !open.contains(negative)) return -rubberBand(-v, limit);
      return v;
    }

    return Offset(
      axis(raw.dx, SwipeDirection.right, SwipeDirection.left),
      axis(raw.dy, SwipeDirection.down, SwipeDirection.up),
    );
  }

  /// The inverse of [applyRubberBand].
  static Offset removeRubberBand(
    Offset stretched,
    Set<SwipeDirection> open,
    double limit,
  ) {
    double axis(double v, SwipeDirection positive, SwipeDirection negative) {
      if (v > 0 && !open.contains(positive)) return unRubberBand(v, limit);
      if (v < 0 && !open.contains(negative)) return -unRubberBand(-v, limit);
      return v;
    }

    return Offset(
      axis(stretched.dx, SwipeDirection.right, SwipeDirection.left),
      axis(stretched.dy, SwipeDirection.down, SwipeDirection.up),
    );
  }

  /// Progress toward each open direction: distance dragged that way divided by
  /// the commit distance, clamped to 0..1.
  ///
  /// Each direction is computed on its own, so the result is continuous
  /// everywhere, including across the diagonal.
  static SwipeProgress progress({
    required Offset offset,
    required Size cardSize,
    required Set<SwipeDirection> open,
    required double threshold,
  }) {
    if (offset == Offset.zero) return SwipeProgress.zero;
    double of(SwipeDirection d) {
      if (!open.contains(d)) return 0;
      final extent = d.isHorizontal ? cardSize.width : cardSize.height;
      if (extent <= 0) return 0;
      final p = d.distance(offset) / (extent * threshold);
      return p.clamp(0.0, 1.0);
    }

    return SwipeProgress(
      left: of(SwipeDirection.left),
      right: of(SwipeDirection.right),
      up: of(SwipeDirection.up),
      down: of(SwipeDirection.down),
    );
  }

  /// Decides what a release means: the direction to commit, or null to spring
  /// back.
  ///
  /// The card is judged by where it is *heading*, `offset + velocity *
  /// projectionTime`, the way native scroll views project a fling. A quick
  /// flick therefore commits after a short distance, while a slow drag has to
  /// go further, and dragging out then flicking back cancels.
  static SwipeDirection? decide({
    required Offset offset,
    required Offset velocity,
    required Size cardSize,
    required Set<SwipeDirection> open,
    required double threshold,
    required double projectionTime,
    required double minDistance,
  }) {
    final projected = offset + velocity * projectionTime;
    if (projected == Offset.zero) return null;
    final direction = SwipeDirection.fromOffset(projected);
    if (!open.contains(direction)) return null;
    if (direction.distance(offset) < minDistance) return null;
    final extent = direction.isHorizontal ? cardSize.width : cardSize.height;
    return direction.distance(projected) >= extent * threshold
        ? direction
        : null;
  }
}

/// The stack's measurements.
class SwipeGeometry {
  /// Creates measurements for a stack of [size] whose top card is [cardRect].
  const SwipeGeometry({required this.size, required this.cardRect});

  /// Measurements for a stack of [size] that keeps [reserve] free.
  factory SwipeGeometry.forStack(Size size, EdgeInsets reserve) {
    final rect = Rect.fromLTRB(
      reserve.left,
      reserve.top,
      math.max(reserve.left, size.width - reserve.right),
      math.max(reserve.top, size.height - reserve.bottom),
    );
    return SwipeGeometry(size: size, cardRect: rect);
  }

  /// The stack's size.
  final Size size;

  /// Where the top card rests, in stack coordinates.
  final Rect cardRect;

  /// The top card's size.
  Size get cardSize => cardRect.size;

  /// Extra distance, beyond fully off the stack, that a leaving card travels,
  /// so its tilted corners are gone too.
  double get exitMargin =>
      math.max(cardRect.width, cardRect.height) * 0.25 + 24;

  /// How far, in pixels, a card must move toward [direction] to be fully off
  /// the stack (with room for its tilt).
  double exitDistance(SwipeDirection direction) => switch (direction) {
    SwipeDirection.left => cardRect.right + exitMargin,
    SwipeDirection.right => size.width - cardRect.left + exitMargin,
    SwipeDirection.up => cardRect.bottom + exitMargin,
    SwipeDirection.down => size.height - cardRect.top + exitMargin,
  };

  /// Where a card leaving toward [direction] is headed. Along the direction it
  /// goes fully off-screen; on the other axis it keeps drifting the way it was
  /// already moving, so the exit continues the gesture instead of turning.
  Offset exitTarget(SwipeDirection direction, Offset current, Offset velocity) {
    final along = exitDistance(direction);
    double drift(double v, double extent) =>
        (v * 0.12).clamp(-extent * 0.5, extent * 0.5);
    if (direction.isHorizontal) {
      return Offset(
        direction.vector.dx * along,
        current.dy + drift(velocity.dy, cardRect.height),
      );
    }
    return Offset(
      current.dx + drift(velocity.dx, cardRect.width),
      direction.vector.dy * along,
    );
  }
}

/// A gentle curve from [from] to [to], bowed upward, used to fly a card into a
/// target.
class SwipePath {
  /// Creates the path. [arc] is the bow as a fraction of the path length.
  SwipePath({required this.from, required this.to, double arc = 0.2})
    : control = _control(from, to, arc);

  /// Start.
  final Offset from;

  /// End.
  final Offset to;

  /// The control point of the quadratic curve.
  final Offset control;

  static Offset _control(Offset from, Offset to, double arc) {
    final d = to - from;
    final length = d.distance;
    final mid = Offset.lerp(from, to, 0.5)!;
    if (length < 1 || arc == 0) return mid;
    var normal = Offset(-d.dy, d.dx) / length;
    if (normal.dy > 0 || (normal.dy == 0 && normal.dx < 0)) normal = -normal;
    return mid + normal * (length * arc);
  }

  /// The point at progress [p] (0 to 1).
  Offset at(double p) {
    final q = 1 - p;
    return from * (q * q) + control * (2 * q * p) + to * (p * p);
  }

  /// The direction of travel at progress [p], scaled by the curve.
  Offset tangentAt(double p) =>
      (control - from) * (2 * (1 - p)) + (to - control) * (2 * p);

  /// Converts a pixel [velocity] into progress per second along the path at
  /// its start, so a release hands its speed to the path without a jump.
  double progressVelocityFor(Offset velocity) {
    final t = tangentAt(0);
    final n2 = t.distanceSquared;
    if (n2 < 1e-6) return 0;
    return math.max(0, (velocity.dx * t.dx + velocity.dy * t.dy) / n2);
  }
}
