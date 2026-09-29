import 'dart:ui';

/// A direction a card can be swiped in.
///
/// Directions are physical (screen) directions; they do not flip in
/// right-to-left layouts.
enum SwipeDirection {
  /// Toward the left edge.
  left(Offset(-1, 0)),

  /// Toward the right edge.
  right(Offset(1, 0)),

  /// Toward the top edge.
  up(Offset(0, -1)),

  /// Toward the bottom edge.
  down(Offset(0, 1));

  const SwipeDirection(this.vector);

  /// Unit vector pointing this way.
  final Offset vector;

  /// Whether this is [left] or [right].
  bool get isHorizontal => this == left || this == right;

  /// The opposite direction.
  SwipeDirection get opposite => switch (this) {
    SwipeDirection.left => SwipeDirection.right,
    SwipeDirection.right => SwipeDirection.left,
    SwipeDirection.up => SwipeDirection.down,
    SwipeDirection.down => SwipeDirection.up,
  };

  /// How far [offset] points this way (negative when it points away).
  double distance(Offset offset) =>
      offset.dx * vector.dx + offset.dy * vector.dy;

  /// The direction [offset] mostly points to. Ties go to the horizontal axis.
  static SwipeDirection fromOffset(Offset offset) {
    if (offset.dx.abs() >= offset.dy.abs()) {
      return offset.dx >= 0 ? SwipeDirection.right : SwipeDirection.left;
    }
    return offset.dy >= 0 ? SwipeDirection.down : SwipeDirection.up;
  }
}
