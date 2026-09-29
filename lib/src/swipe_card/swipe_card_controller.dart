import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'swipe_direction.dart';
import 'swipe_progress.dart';

/// What a [SwipeCardController] drives. Implemented by the stack.
abstract interface class SwipeHandle {
  /// Swipes the top card toward [direction].
  void swipe(SwipeDirection direction, Offset? velocity);

  /// Brings the last swiped card back.
  void undo();

  /// Brings several swiped cards back, one after another.
  void rewind(int? count, Duration stagger);

  /// Starts the deck over from the items.
  void reset();
}

/// Controls a `SwipeCardStack` from outside (for example from buttons) and
/// exposes its live state.
///
/// Create it once, pass it to the stack, and [dispose] it when done.
class SwipeCardController {
  final ValueNotifier<SwipeProgress> _progress = ValueNotifier<SwipeProgress>(
    SwipeProgress.zero,
  );
  final ValueNotifier<SwipeConsume?> _consuming = ValueNotifier<SwipeConsume?>(
    null,
  );
  final ValueNotifier<int> _remaining = ValueNotifier<int>(0);
  final ValueNotifier<bool> _undoAvailable = ValueNotifier<bool>(false);
  SwipeHandle? _handle;

  /// How far the top card is dragged toward each direction, live. Listen to it
  /// to make a button react as a card approaches.
  ValueListenable<SwipeProgress> get progress => _progress;

  /// The card currently travelling into a `SwipeTarget`, if any.
  ValueListenable<SwipeConsume?> get consuming => _consuming;

  /// Cards left in the deck.
  ValueListenable<int> get remaining => _remaining;

  /// Whether [undo] would do something.
  ValueListenable<bool> get undoAvailable => _undoAvailable;

  /// Whether a stack is using this controller.
  bool get isAttached => _handle != null;

  /// Swipes the top card toward [direction], with the same behavior and
  /// animation as a drag. [velocity] (pixels per second) is the launch speed;
  /// it defaults to the physics' programmatic speed.
  ///
  /// Ignored when the direction has no behavior, the deck is empty, or the
  /// user is holding the card.
  void swipe(SwipeDirection direction, {Offset? velocity}) =>
      _handle?.swipe(direction, velocity);

  /// Brings the last swiped card back from where it left.
  void undo() => _handle?.undo();

  /// Brings swiped cards back one after another, most recent first, so the
  /// deck ends up as it was. [count] limits how many (default: all that can
  /// be undone) and [stagger] is the pause between cards.
  ///
  /// Each card returns the way an undo does, and they overlap: a card keeps
  /// arriving while the next one is already on its way. Touching the top card
  /// stops the rewind.
  void rewind({
    int? count,
    Duration stagger = const Duration(milliseconds: 90),
  }) => _handle?.rewind(count, stagger);

  /// Starts the deck over from the stack's items.
  void reset() => _handle?.reset();

  /// Connects a stack. Called by the stack; do not call it yourself.
  @internal
  void attach(SwipeHandle handle) => _handle = handle;

  /// Disconnects a stack. Called by the stack.
  @internal
  void detach(SwipeHandle handle) {
    if (identical(_handle, handle)) _handle = null;
  }

  /// Live values written by the stack. Not for app code.
  @internal
  ValueNotifier<SwipeProgress> get progressNotifier => _progress;

  /// See [progressNotifier].
  @internal
  ValueNotifier<SwipeConsume?> get consumingNotifier => _consuming;

  /// See [progressNotifier].
  @internal
  ValueNotifier<int> get remainingNotifier => _remaining;

  /// See [progressNotifier].
  @internal
  ValueNotifier<bool> get undoAvailableNotifier => _undoAvailable;

  /// Releases the notifiers.
  void dispose() {
    _progress.dispose();
    _consuming.dispose();
    _remaining.dispose();
    _undoAvailable.dispose();
  }
}
