import 'package:flutter/foundation.dart';

import 'swipe_direction.dart';

/// Lets code outside a [SwipeCardStack] swipe or undo cards, for example from
/// "like" and "nope" buttons.
class SwipeCardController {
  ValueGetter<bool>? _canUndo;
  ValueChanged<SwipeDirection>? _swipe;
  VoidCallback? _undo;

  /// Wires the controller to a stack. Called by [SwipeCardStack]; do not call
  /// it yourself.
  @internal
  void attach({
    required ValueChanged<SwipeDirection> swipe,
    required VoidCallback undo,
    required ValueGetter<bool> canUndo,
  }) {
    _swipe = swipe;
    _undo = undo;
    _canUndo = canUndo;
  }

  /// Detaches from a stack. Called by [SwipeCardStack].
  @internal
  void detach() {
    _swipe = null;
    _undo = null;
    _canUndo = null;
  }

  /// Whether the controller is attached to a stack.
  bool get isAttached => _swipe != null;

  /// Whether a previous swipe can be undone.
  bool get canUndo => _canUndo?.call() ?? false;

  /// Animates the top card off-screen in [direction].
  ///
  /// Ignored if no card remains, an animation is running, or [direction] is
  /// not allowed by the stack.
  void swipe(SwipeDirection direction) => _swipe?.call(direction);

  /// Brings the last swiped card back.
  void undo() => _undo?.call();
}
