import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'swipe_direction.dart';

/// How far the top card has been dragged toward each direction, as a value
/// from 0 to 1 per direction. 1 means the commit threshold is reached.
///
/// The four values are independent and continuous, so an overlay built from
/// them never flickers when a drag crosses the diagonal: LIKE fades out while
/// SKIP fades in, instead of one snapping to the other.
@immutable
class SwipeProgress {
  /// Creates a progress value.
  const SwipeProgress({
    this.left = 0,
    this.right = 0,
    this.up = 0,
    this.down = 0,
  });

  /// Nothing dragged.
  static const SwipeProgress zero = SwipeProgress();

  /// Progress toward the left edge.
  final double left;

  /// Progress toward the right edge.
  final double right;

  /// Progress toward the top edge.
  final double up;

  /// Progress toward the bottom edge.
  final double down;

  /// Progress toward [direction].
  double operator [](SwipeDirection direction) => switch (direction) {
    SwipeDirection.left => left,
    SwipeDirection.right => right,
    SwipeDirection.up => up,
    SwipeDirection.down => down,
  };

  /// The largest of the four values.
  double get max => math.max(math.max(left, right), math.max(up, down));

  /// Whether the card has moved toward any direction.
  bool get isActive => max > 0;

  /// The direction with the largest progress, or null when nothing moved.
  SwipeDirection? get dominant {
    final m = max;
    if (m <= 0) return null;
    if (right == m) return SwipeDirection.right;
    if (left == m) return SwipeDirection.left;
    if (down == m) return SwipeDirection.down;
    return SwipeDirection.up;
  }

  @override
  bool operator ==(Object other) =>
      other is SwipeProgress &&
      other.left == left &&
      other.right == right &&
      other.up == up &&
      other.down == down;

  @override
  int get hashCode => Object.hash(left, right, up, down);

  @override
  String toString() =>
      'SwipeProgress(left: $left, right: $right, up: $up, down: $down)';
}

/// A card currently being consumed by a [SwipeTarget].
@immutable
class SwipeConsume {
  /// Creates the state.
  const SwipeConsume({required this.direction, required this.progress});

  /// The direction whose behavior consumes the card.
  final SwipeDirection direction;

  /// How far the card is on its way, from 0 (leaving) to 1 (arrived).
  final double progress;

  @override
  bool operator ==(Object other) =>
      other is SwipeConsume &&
      other.direction == direction &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(direction, progress);
}
