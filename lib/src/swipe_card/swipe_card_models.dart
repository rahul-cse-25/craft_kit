part of 'swipe_card_stack.dart';

class _Entry<T> {
  _Entry(this.item, this.itemKey) : hostKey = itemKey;

  T item;
  final Key itemKey;

  /// The key of the card's widget in the stack. It normally equals [itemKey];
  /// a card sent to the back gets a fresh one so the old (leaving) widget and
  /// the new (waiting) widget do not collide.
  Key hostKey;

  /// Marks the card's picture, so it can be captured for the genie.
  final GlobalKey boundaryKey = GlobalKey();

  /// A returning card that is still moving while another card has already
  /// been placed above it.
  _Arrival? arrival;

  /// A card pouring back out of a button. While it runs, the live card is not
  /// shown; the genie drawing stands in for it.
  _GenieRun? genieIn;
}

class _RevKey extends LocalKey {
  const _RevKey(this.base, this.revision);

  final Key base;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is _RevKey && other.base == base && other.revision == revision;

  @override
  int get hashCode => Object.hash(base, revision);
}

class _Record<T> {
  _Record({
    required this.entry,
    required this.direction,
    required this.outcome,
    required this.endPose,
    required this.tilt,
    this.target,
    this.targetRect,
  });

  final _Entry<T> entry;
  final SwipeDirection direction;
  final SwipeOutcome outcome;

  /// Where the card ended up, so an undo can bring it back from there.
  final SwipePose endPose;

  /// The tilt the card had, so an undo returns it with the same one.
  final double tilt;

  /// For a consumed card: where it went, and the rectangle that was in stack
  /// coordinates then (used when the target is no longer on screen).
  final SwipeTarget? target;
  final Rect? targetRect;

  /// A picture of a genie-consumed card, kept so it can pour back out. Only
  /// the most recent few are kept.
  ui.Image? image;
}

class _PoseNotifier extends ChangeNotifier {
  _PoseNotifier(this._pose);

  SwipePose _pose;

  SwipePose get pose => _pose;

  set pose(SwipePose value) {
    if (_pose == value) return;
    _pose = value;
    notifyListeners();
  }
}

/// A card whose motion continues behind the top card.
class _Arrival {
  _Arrival({required this.move, required this.start, required SwipePose pose})
    : pose = _PoseNotifier(pose);

  final SwipeMove move;

  /// Clock time the move started; NaN until the next frame picks it up.
  double start;
  final _PoseNotifier pose;
}

/// A captured card and the geometry of its genie. Owns the picture.

/// The live state every card widget listens to. Changing it never rebuilds a
/// card; it only re-runs the cheap transform builders.
class _Motion extends ChangeNotifier {
  /// Pose of the top card.
  SwipePose pose = SwipePose.identity;

  /// Cards behind move up by `p` while the top card is being dragged away.
  double p = 0;

  /// The remainder of a promotion still to animate after a commit or undo.
  double s = 0;

  /// Drag progress toward each direction.
  SwipeProgress progress = SwipeProgress.zero;

  void changed() => notifyListeners();
}

class _Leaver<T> {
  _Leaver({
    required this.entry,
    required this.move,
    required this.direction,
    required this.outcome,
    required this.behavior,
    required this.event,
    required SwipePose pose,
    required this.slot,
    required this.start,
    this.genie,
    this.record,
  }) : pose = _PoseNotifier(pose);

  final _Entry<T> entry;
  final SwipeMove move;
  final SwipeDirection direction;
  final SwipeOutcome outcome;
  final SwipeBehavior<T> behavior;
  final SwipeEvent<T> event;
  final _PoseNotifier pose;

  /// The slot the card was in when it left, so it does not jump.
  final SwipeSlot slot;

  /// Set when the card pours into its target instead of shrinking.
  final _GenieRun? genie;
  final _Record<T>? record;

  /// Clock time the move started; NaN until the next frame picks it up.
  double start;
}

/// A cached card widget. Reusing the same instance lets Flutter skip
/// rebuilding an unchanged subtree.
class _Cached {
  _Cached(this.item, this.depth, this.leaving, this.widget);

  final Object? item;
  final int depth;
  final bool leaving;
  final Widget widget;
}

/// Draws a captured card warped by [SwipeGenie].
