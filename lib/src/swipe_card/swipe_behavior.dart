import 'package:flutter/widgets.dart';

import 'swipe_direction.dart';

/// What happens to a card when it is swiped in a direction.
enum SwipeOutcome {
  /// The card flies off the screen and leaves the deck.
  dismiss,

  /// The card shrinks into a [SwipeTarget] (for example a button) and leaves
  /// the deck.
  consume,

  /// The card runs your callback, then springs back onto the stack. It never
  /// leaves the deck.
  springBack,

  /// The card flies off and re-enters at the bottom of the deck.
  sendToBack,
}

/// A place a card can be consumed into.
///
/// Give it the [GlobalKey] of the widget (typically a button) the card should
/// travel to. The position is measured once when the card is released, so
/// layout changes between swipes are always respected.
@immutable
class SwipeTarget {
  /// Targets the widget that has [key].
  const SwipeTarget({
    required GlobalKey this.key,
    this.alignment = Alignment.center,
    this.endScale = 0.08,
    this.arc = 0.2,
    this.fade = true,
  }) : rect = null;

  /// Targets a rectangle, in global coordinates, computed on demand.
  const SwipeTarget.rect(
    Rect Function() this.rect, {
    this.alignment = Alignment.center,
    this.endScale = 0.08,
    this.arc = 0.2,
    this.fade = true,
  }) : key = null;

  /// The widget to travel to.
  final GlobalKey? key;

  /// Computes the target rectangle in global coordinates.
  final Rect Function()? rect;

  /// Where in the target rectangle the card ends up.
  final Alignment alignment;

  /// Scale of the card on arrival, relative to its resting size.
  final double endScale;

  /// How much the path bows, as a fraction of its length. 0 is a straight
  /// line.
  final double arc;

  /// Whether the card fades out over the last part of the path.
  final bool fade;

  /// The point the card travels to, in global coordinates, or null when the
  /// target is not on screen.
  Offset? resolvePoint() {
    Rect? bounds;
    final rectFn = rect;
    if (rectFn != null) {
      bounds = rectFn();
    } else {
      final render = key?.currentContext?.findRenderObject();
      if (render is RenderBox && render.attached && render.hasSize) {
        bounds = render.localToGlobal(Offset.zero) & render.size;
      }
    }
    if (bounds == null) return null;
    return Offset(
      bounds.center.dx + alignment.x * bounds.width / 2,
      bounds.center.dy + alignment.y * bounds.height / 2,
    );
  }
}

/// Describes a completed swipe.
@immutable
class SwipeEvent<T> {
  /// Creates an event.
  const SwipeEvent({
    required this.item,
    required this.key,
    required this.direction,
    required this.outcome,
    required this.velocity,
    required this.programmatic,
    required this.remaining,
  });

  /// The swiped item.
  final T item;

  /// The item's key.
  final Key key;

  /// The direction it was swiped in.
  final SwipeDirection direction;

  /// What happened to it.
  final SwipeOutcome outcome;

  /// The velocity, in pixels per second, of the card at release.
  final Offset velocity;

  /// True when triggered by the controller (a button) rather than by touch.
  final bool programmatic;

  /// Cards left in the deck after this swipe.
  final int remaining;
}

/// Called with a [SwipeEvent].
typedef SwipeCallback<T> = void Function(SwipeEvent<T> event);

/// Decides whether an item may be swiped; return false to send it back.
typedef SwipeGuard<T> = bool Function(T item);

/// What one direction does.
///
/// A direction without a behavior cannot be swiped: dragging that way
/// stretches the card with resistance and it springs back.
@immutable
class SwipeBehavior<T> {
  /// The card flies off the screen.
  const SwipeBehavior.dismiss({this.onCommit, this.guard})
    : outcome = SwipeOutcome.dismiss,
      target = null,
      onArrive = null;

  /// The card shrinks into [target]. If the target is not on screen the card
  /// flies off instead.
  const SwipeBehavior.consume({
    required SwipeTarget this.target,
    this.onCommit,
    this.onArrive,
    this.guard,
  }) : outcome = SwipeOutcome.consume;

  /// The card runs [onCommit], then springs back onto the stack.
  const SwipeBehavior.springBack({this.onCommit, this.guard})
    : outcome = SwipeOutcome.springBack,
      target = null,
      onArrive = null;

  /// The card flies off and comes back at the bottom of the deck.
  const SwipeBehavior.sendToBack({this.onCommit, this.guard})
    : outcome = SwipeOutcome.sendToBack,
      target = null,
      onArrive = null;

  /// What happens.
  final SwipeOutcome outcome;

  /// Where a consumed card travels. Only for [SwipeOutcome.consume].
  final SwipeTarget? target;

  /// Called the moment the swipe commits, before the stack-wide `onSwipe`.
  final SwipeCallback<T>? onCommit;

  /// Called when a consumed card reaches its target.
  final void Function(T item)? onArrive;

  /// Return false to refuse this swipe for an item; the card springs back.
  final SwipeGuard<T>? guard;
}

/// Ready-made behavior maps.
abstract final class SwipeBehaviors {
  /// [SwipeBehavior.dismiss] for each of [directions].
  static Map<SwipeDirection, SwipeBehavior<T>> dismiss<T>(
    Iterable<SwipeDirection> directions,
  ) => <SwipeDirection, SwipeBehavior<T>>{
    for (final d in directions) d: SwipeBehavior<T>.dismiss(),
  };

  /// Dismiss left and right.
  static Map<SwipeDirection, SwipeBehavior<T>> horizontal<T>() =>
      dismiss<T>(const [SwipeDirection.left, SwipeDirection.right]);

  /// Dismiss in all four directions.
  static Map<SwipeDirection, SwipeBehavior<T>> all<T>() =>
      dismiss<T>(SwipeDirection.values);
}
