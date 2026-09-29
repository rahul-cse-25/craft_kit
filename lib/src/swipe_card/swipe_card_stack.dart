import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'engine/swipe_math.dart';
import 'engine/swipe_moves.dart';
import 'swipe_behavior.dart';
import 'swipe_card_controller.dart';
import 'swipe_direction.dart';
import 'swipe_haptics.dart';
import 'swipe_layout.dart';
import 'swipe_physics.dart';
import 'swipe_progress.dart';

/// Facts about the card being built.
@immutable
class SwipeCardInfo {
  /// Creates the info.
  const SwipeCardInfo({
    required this.depth,
    required this.isTop,
    required this.isLeaving,
    required this.progress,
  });

  /// 0 for the top card, 1 for the one behind it, and so on.
  final int depth;

  /// Whether this is the card the user can drag.
  final bool isTop;

  /// Whether the card has been swiped and is on its way out.
  final bool isLeaving;

  /// Live drag progress toward each direction. Wrap the parts of a card that
  /// should react in a `ValueListenableBuilder`; the card itself is not
  /// rebuilt while it moves.
  final ValueListenable<SwipeProgress> progress;
}

/// Builds the card for [item].
///
/// It is called when the deck changes (a card is swiped, undone, added), never
/// while a card is being dragged or animated.
typedef SwipeCardBuilder<T> =
    Widget Function(BuildContext context, T item, SwipeCardInfo info);

/// Builds the overlay drawn over the top card while it is dragged, for
/// example the LIKE and NOPE stamps.
///
/// It is rebuilt as the card moves and only while [progress] is active, so
/// keep it light.
typedef SwipeOverlayBuilder =
    Widget Function(BuildContext context, SwipeProgress progress);

/// Called once for each item that is about to come up, so images can be
/// precached.
typedef SwipePreloadCallback<T> =
    void Function(BuildContext context, T item, int depth);

/// A deck of cards the user can swipe, with a spring-driven feel.
///
/// The stack is generic: the card, the overlay, the look of the cards behind
/// the top one ([layout]), and what each direction does ([behaviors]) are all
/// supplied by the caller.
///
/// It fills the space it is given, which must be bounded.
class SwipeCardStack<T> extends StatefulWidget {
  /// Creates a swipeable deck.
  const SwipeCardStack({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.itemKey,
    this.controller,
    this.behaviors,
    this.layout = const CascadeLayout(),
    this.physics = const SwipePhysics(),
    this.haptics = const SwipeHaptics(),
    this.overlayBuilder,
    this.emptyBuilder,
    this.onSwipe,
    this.onSwipeEnd,
    this.onUndo,
    this.onEnd,
    this.onNeedMore,
    this.needMoreThreshold = 3,
    this.onPreload,
    this.preloadCount = 2,
    this.historyLimit = 20,
    this.enabled = true,
    this.enableKeyboard = true,
    this.autofocus = false,
    this.directionLabel,
  }) : assert(historyLimit >= 0),
       assert(needMoreThreshold >= 0),
       assert(preloadCount >= 0);

  /// The cards, top first.
  ///
  /// Items are matched by [itemKey], not by position, so replacing the list
  /// with an equal one never resets the deck. New items join the end; items
  /// that disappear are removed. Call [SwipeCardController.reset] to start
  /// over.
  final List<T> items;

  /// Builds one card.
  final SwipeCardBuilder<T> itemBuilder;

  /// A stable identity for an item. Defaults to `ValueKey(item)`, which needs
  /// items with a meaningful `==` and `hashCode` (or the same instances).
  /// Keys must be unique within [items].
  final Key Function(T item)? itemKey;

  /// Lets outside code swipe, undo, reset, and observe the stack.
  final SwipeCardController? controller;

  /// What each direction does. A direction that is not here cannot be swiped;
  /// dragging that way stretches the card and it springs back.
  ///
  /// Defaults to dismissing left and right.
  final Map<SwipeDirection, SwipeBehavior<T>>? behaviors;

  /// How the cards behind the top one look.
  final SwipeStackLayout layout;

  /// How the cards feel.
  final SwipePhysics physics;

  /// Haptic feedback.
  final SwipeHaptics haptics;

  /// Drawn over the top card while it is dragged.
  final SwipeOverlayBuilder? overlayBuilder;

  /// Shown when the deck is empty.
  final WidgetBuilder? emptyBuilder;

  /// Called the moment a swipe commits, for every outcome.
  final SwipeCallback<T>? onSwipe;

  /// Called when a swiped card has finished leaving (or arrived at its
  /// target).
  final SwipeCallback<T>? onSwipeEnd;

  /// Called when a card is brought back by [SwipeCardController.undo].
  final SwipeCallback<T>? onUndo;

  /// Called when the last card has been swiped away.
  final VoidCallback? onEnd;

  /// Called with the number of cards left when it drops to
  /// [needMoreThreshold], so more can be loaded. Append the new items to
  /// [items].
  final void Function(int remaining)? onNeedMore;

  /// See [onNeedMore].
  final int needMoreThreshold;

  /// Called once per item as it comes within [preloadCount] cards of being
  /// shown.
  final SwipePreloadCallback<T>? onPreload;

  /// How many cards beyond the visible ones to preload.
  final int preloadCount;

  /// How many swipes can be undone.
  final int historyLimit;

  /// Whether the user can drag the top card. Programmatic swipes still work.
  final bool enabled;

  /// Whether the arrow keys swipe while the stack has focus.
  final bool enableKeyboard;

  /// Whether the stack takes keyboard focus on first build.
  final bool autofocus;

  /// Accessibility label for swiping toward a direction. Defaults to English
  /// ("Swipe left").
  final String Function(SwipeDirection direction)? directionLabel;

  @override
  State<SwipeCardStack<T>> createState() => _SwipeCardStackState<T>();
}

// ---------------------------------------------------------------------------
// Internal models
// ---------------------------------------------------------------------------

class _Entry<T> {
  _Entry(this.item, this.itemKey) : hostKey = itemKey;

  T item;
  final Key itemKey;

  /// The key of the card's widget in the stack. It normally equals [itemKey];
  /// a card sent to the back gets a fresh one so the old (leaving) widget and
  /// the new (waiting) widget do not collide.
  Key hostKey;
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
  });

  final _Entry<T> entry;
  final SwipeDirection direction;
  final SwipeOutcome outcome;

  /// Where the card ended up, so an undo can bring it back from there.
  final SwipePose endPose;
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
    required this.start,
  }) : pose = _PoseNotifier(pose);

  final _Entry<T> entry;
  final SwipeMove move;
  final SwipeDirection direction;
  final SwipeOutcome outcome;
  final SwipeBehavior<T> behavior;
  final SwipeEvent<T> event;
  final _PoseNotifier pose;

  /// Clock time the move started; NaN until the next frame picks it up.
  double start;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _SwipeCardStackState<T> extends State<SwipeCardStack<T>>
    with SingleTickerProviderStateMixin
    implements SwipeHandle {
  late final Ticker _ticker;
  final _Motion _motion = _Motion();

  final List<_Entry<T>> _deck = <_Entry<T>>[];
  final List<_Leaver<T>> _leavers = <_Leaver<T>>[];
  final List<_Record<T>> _history = <_Record<T>>[];
  final Set<Key> _dismissed = <Key>{};
  final Set<Key> _preloaded = <Key>{};

  late SwipeCardController _controller;
  SwipeCardController? _ownedController;

  late Map<SwipeDirection, SwipeBehavior<T>> _behaviors;
  late Set<SwipeDirection> _open;

  SwipeGeometry? _geometry;
  bool _reduceMotion = false;

  // Animation clock. `_now` is the time of the latest frame.
  double _carry = 0;
  double _now = 0;

  SwipeMove? _topMove;
  double _topStart = double.nan;

  ScalarSpring? _sMove;
  double _sStart = double.nan;
  double _s = 0;

  /// Whether cards behind follow the top card's drag progress. False while an
  /// undone card is flying back, when the promotion is animated on its own.
  bool _pFromPose = true;

  bool _pointerDown = false;
  bool _dragStarted = false;
  Offset _raw = Offset.zero;
  double _tilt = 1;
  final Set<SwipeDirection> _crossed = <SwipeDirection>{};

  int _revision = 0;
  bool _needMoreSent = false;
  bool _endSent = false;
  bool _preloadScheduled = false;
  bool _publishScheduled = false;

  // ---- lifecycle ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? (_ownedController = SwipeCardController());
    _controller.attach(this);
    _ticker = createTicker(_onTick);
    _resolveBehaviors();
    _syncItems(initial: true);
    _schedulePublish();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read here, not from a frame callback: the element may be inactive by
    // then (for example when a page swaps out).
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void didUpdateWidget(SwipeCardStack<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _controller.detach(this);
      _ownedController?.dispose();
      _ownedController = null;
      _controller =
          widget.controller ?? (_ownedController = SwipeCardController());
      _controller.attach(this);
      _schedulePublish();
    }
    _resolveBehaviors();
    if (!identical(oldWidget.items, widget.items) ||
        oldWidget.items.length != widget.items.length) {
      _syncItems();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.detach(this);
    _ownedController?.dispose();
    for (final leaver in _leavers) {
      leaver.pose.dispose();
    }
    _motion.dispose();
    super.dispose();
  }

  void _resolveBehaviors() {
    _behaviors = widget.behaviors ?? SwipeBehaviors.horizontal<T>();
    _open = _behaviors.keys.toSet();
  }

  // ---- deck model ---------------------------------------------------------

  Key _keyOf(T item) => widget.itemKey?.call(item) ?? ValueKey<T>(item);

  /// Reconciles the deck with [SwipeCardStack.items]: keeps order and
  /// progress, appends new items, drops missing ones, never resurrects a
  /// swiped card.
  void _syncItems({bool initial = false}) {
    final incoming = <Key, T>{};
    for (final item in widget.items) {
      final key = _keyOf(item);
      assert(
        !incoming.containsKey(key),
        'SwipeCardStack items must have unique keys; "$key" appears twice. '
        'Provide itemKey or make the items distinct.',
      );
      incoming[key] = item;
    }

    if (initial) {
      _deck
        ..clear()
        ..addAll(incoming.entries.map((e) => _Entry<T>(e.value, e.key)));
      return;
    }

    _deck.removeWhere((e) => !incoming.containsKey(e.itemKey));
    _dismissed.removeWhere((k) => !incoming.containsKey(k));
    _preloaded.removeWhere((k) => !incoming.containsKey(k));
    _history.removeWhere((r) => !incoming.containsKey(r.entry.itemKey));

    final present = <Key>{for (final e in _deck) e.itemKey};
    for (final e in _deck) {
      e.item = incoming[e.itemKey] as T;
    }
    for (final entry in incoming.entries) {
      if (present.contains(entry.key) || _dismissed.contains(entry.key)) {
        continue;
      }
      _deck.add(_Entry<T>(entry.value, entry.key));
    }

    if (_deck.length > widget.needMoreThreshold) _needMoreSent = false;
    if (_deck.isNotEmpty) _endSent = false;
    _schedulePublish();
  }

  void _schedulePublish() {
    if (_publishScheduled) return;
    _publishScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _publishScheduled = false;
      if (mounted) _publishCounts();
    });
  }

  void _publishCounts() {
    _controller.remainingNotifier.value = _deck.length;
    _controller.undoAvailableNotifier.value = _history.isNotEmpty;
  }

  // ---- clock and ticker ---------------------------------------------------

  void _startTicker() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _stopTicker() {
    if (_ticker.isActive) {
      _ticker.stop();
      _carry = _now;
    }
  }

  /// A start time for a move begun now. It is left for the next frame to fill
  /// in, so a move never starts "in the past" and skips ahead. With reduced
  /// motion it is set far in the past so the move finishes on the next frame.
  double get _newStart => _reduceMotion ? _now - 1e6 : double.nan;

  void _onTick(Duration elapsed) {
    _now = _carry + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    var active = false;

    final move = _topMove;
    if (move != null) {
      if (_topStart.isNaN) _topStart = _now;
      final t = _now - _topStart;
      if (move.isDone(t)) {
        _topMove = null;
        _pFromPose = true;
        _setTopPose(move.finalPose);
      } else {
        _setTopPose(move.at(t));
        active = true;
      }
    }

    final promotion = _sMove;
    if (promotion != null) {
      if (_sStart.isNaN) _sStart = _now;
      final t = _now - _sStart;
      if (promotion.isDone(t)) {
        _sMove = null;
        _s = 0;
      } else {
        _s = promotion.value(t);
        active = true;
      }
      _motion.s = _s;
      _motion.changed();
    }

    for (var i = _leavers.length - 1; i >= 0; i--) {
      final leaver = _leavers[i];
      if (leaver.start.isNaN) leaver.start = _now;
      final t = _now - leaver.start;
      if (leaver.move.isDone(t)) {
        leaver.pose.pose = leaver.move.finalPose;
        _finishLeaver(leaver);
        _leavers.removeAt(i);
      } else {
        leaver.pose.pose = leaver.move.at(t);
        final m = leaver.move;
        if (m is PathMove) {
          _controller.consumingNotifier.value = SwipeConsume(
            direction: leaver.direction,
            progress: m.progressAt(t),
          );
        }
        active = true;
      }
    }

    if (!active) _stopTicker();
  }

  void _finishLeaver(_Leaver<T> leaver) {
    if (leaver.outcome == SwipeOutcome.consume) {
      _controller.consumingNotifier
        ..value = SwipeConsume(direction: leaver.direction, progress: 1)
        ..value = null;
      leaver.behavior.onArrive?.call(leaver.entry.item);
    }
    widget.onSwipeEnd?.call(leaver.event);
    // Dispose after the frame that stops listening to it.
    final notifier = leaver.pose;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifier.dispose());
    if (mounted) setState(() {});
  }

  // ---- top card pose ------------------------------------------------------

  double _rotationFor(Offset offset) {
    final g = _geometry;
    if (g == null) return 0;
    final half = g.cardRect.width / 2;
    if (half <= 0) return 0;
    return (offset.dx / half).clamp(-1.0, 1.0) *
        widget.physics.maxAngle *
        _tilt;
  }

  void _setTopPose(SwipePose pose, {bool fromDrag = false}) {
    final g = _geometry;
    _motion.pose = pose;
    final progress =
        g == null
            ? SwipeProgress.zero
            : SwipeMath.progress(
              offset: pose.offset,
              cardSize: g.cardSize,
              open: _open,
              threshold: widget.physics.commitThreshold,
            );
    _motion.progress = progress;
    _motion.p = _pFromPose ? progress.max : 0;
    _motion.changed();
    _controller.progressNotifier.value = progress;

    if (fromDrag) {
      for (final d in _open) {
        final v = progress[d];
        if (v >= 1 && _crossed.add(d)) {
          _haptic(widget.haptics.thresholdCrossed);
        } else if (v < 0.85) {
          _crossed.remove(d);
        }
      }
    }
  }

  void _haptic(SwipeHapticType? type) {
    if (type != null) type.perform();
  }

  void _startTopMove(SwipeMove move) {
    _topMove = move;
    _topStart = _newStart;
    _startTicker();
  }

  /// Starts (or restarts) the promotion remainder at [from], keeping the
  /// speed it already had so a second swipe in quick succession stays smooth.
  void _startPromotion(double from) {
    final old = _sMove;
    final velocity =
        old == null || _sStart.isNaN ? 0.0 : old.velocity(_now - _sStart);
    _s = from;
    _sMove = ScalarSpring(
      from: from,
      velocity: velocity,
      spring: widget.physics.promote.description,
    );
    _sStart = _newStart;
    _motion.s = from;
    _motion.changed();
    _startTicker();
  }

  /// Switches the cards behind to follow the top card's drag again, without
  /// moving them: whatever the drag now contributes is moved into `s`.
  void _enablePFromPose() {
    if (_pFromPose) return;
    _pFromPose = true;
    final g = _geometry;
    if (g == null) return;
    final p =
        SwipeMath.progress(
          offset: _motion.pose.offset,
          cardSize: g.cardSize,
          open: _open,
          threshold: widget.physics.commitThreshold,
        ).max;
    if (p > 0) _startPromotion(_s + p);
  }

  // ---- pointer handling ---------------------------------------------------

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || _deck.isEmpty || _geometry == null) return;
    if (_pointerDown) return;
    _pointerDown = true;
    _dragStarted = false;
    // Catch the card wherever it is, mid-flight or mid-spring.
    _topMove = null;
    _enablePFromPose();
    _raw = SwipeMath.removeRubberBand(
      _motion.pose.offset,
      _open,
      widget.physics.rubberBandLimit,
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    // A tap that never became a drag. (A drag releases from onEnd, which has
    // the velocity.)
    if (_pointerDown && !_dragStarted) _release(Offset.zero);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_pointerDown && !_dragStarted) _release(Offset.zero);
  }

  void _onDragStart(DragStartDetails details) {
    if (!_pointerDown) return;
    _dragStarted = true;
    _crossed.clear();
    final g = _geometry;
    if (widget.physics.grabTilt && g != null) {
      final half = g.cardRect.height / 2;
      final s =
          half <= 0
              ? 0.0
              : ((half - details.localPosition.dy) / half).clamp(-1.0, 1.0);
      // Grab above the middle and the card swings with the finger; grab below
      // and it swings against it. Never quite zero, so it always tilts.
      _tilt = s >= 0 ? 0.5 + 0.5 * s : -0.5 + 0.5 * s;
    } else {
      _tilt = 1;
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_pointerDown) return;
    _raw += details.delta;
    final offset = SwipeMath.applyRubberBand(
      _raw,
      _open,
      widget.physics.rubberBandLimit,
    );
    _setTopPose(
      SwipePose(offset: offset, rotation: _rotationFor(offset)),
      fromDrag: true,
    );
  }

  void _onDragEnd(DragEndDetails details) =>
      _release(details.velocity.pixelsPerSecond);

  void _onDragCancel() => _release(Offset.zero);

  // ---- release and commit -------------------------------------------------

  void _release(Offset velocity) {
    if (!_pointerDown) return;
    _pointerDown = false;
    _dragStarted = false;
    _crossed.clear();
    final g = _geometry;
    if (g == null || _deck.isEmpty) return;

    final direction = SwipeMath.decide(
      offset: _motion.pose.offset,
      velocity: velocity,
      cardSize: g.cardSize,
      open: _open,
      threshold: widget.physics.commitThreshold,
      projectionTime: widget.physics.projectionTime,
      minDistance: widget.physics.minCommitDistance,
    );
    final behavior = direction == null ? null : _behaviors[direction];
    if (direction == null ||
        behavior == null ||
        behavior.guard?.call(_deck.first.item) == false) {
      _springBack(velocity);
      return;
    }
    _commit(direction, velocity: velocity, programmatic: false);
  }

  void _springBack(Offset velocity) {
    _startTopMove(
      SpringMove(
        from: _motion.pose.offset,
        velocity: velocity,
        to: Offset.zero,
        spring: widget.physics.settle.description,
        rotationFor: _rotationFor,
      ),
    );
  }

  void _commit(
    SwipeDirection direction, {
    required Offset velocity,
    required bool programmatic,
  }) {
    final geometry = _geometry!;
    final entry = _deck.first;
    final behavior = _behaviors[direction]!;
    final start = _motion.pose;
    final physics = widget.physics;
    _haptic(widget.haptics.commit);

    var outcome = behavior.outcome;

    // ---- a trigger: run the task, spring back, stay in the deck ----
    if (outcome == SwipeOutcome.springBack) {
      final event = _eventFor(
        entry,
        direction,
        outcome,
        velocity,
        programmatic,
        _deck.length,
      );
      _startTopMove(
        SpringMove(
          from: start.offset,
          velocity: velocity,
          to: Offset.zero,
          spring: physics.settle.description,
          rotationFor: _rotationFor,
        ),
      );
      behavior.onCommit?.call(event);
      widget.onSwipe?.call(event);
      return;
    }

    // ---- the card leaves: build its move ----
    SwipeMove move;
    if (outcome == SwipeOutcome.consume) {
      final target = behavior.target!;
      final global = target.resolvePoint();
      final box = context.findRenderObject();
      if (global != null && box is RenderBox && box.attached) {
        final to = box.globalToLocal(global) - geometry.cardRect.center;
        final path = SwipePath(from: start.offset, to: to, arc: target.arc);
        move = PathMove(
          path: path,
          progressVelocity: path.progressVelocityFor(velocity),
          spring: physics.consume.description,
          fromRotation: start.rotation,
          fromScale: start.scale,
          endScale: target.endScale,
          fade: target.fade,
        );
      } else {
        // The target is not on screen: fall back to leaving.
        outcome = SwipeOutcome.dismiss;
        move = _exitMove(geometry, direction, start, velocity);
      }
    } else {
      move = _exitMove(geometry, direction, start, velocity);
    }

    final leavesDeck = outcome != SwipeOutcome.sendToBack;
    final remaining = leavesDeck ? _deck.length - 1 : _deck.length;
    final event = _eventFor(
      entry,
      direction,
      outcome,
      velocity,
      programmatic,
      remaining,
    );

    // The card becomes a leaver with its own pose, above the deck.
    final leaver = _Leaver<T>(
      entry: entry,
      move: move,
      direction: direction,
      outcome: outcome,
      behavior: behavior,
      event: event,
      pose: start,
      start: _newStart,
    );
    _leavers.add(leaver);

    // Deck bookkeeping.
    _deck.removeAt(0);
    if (outcome == SwipeOutcome.sendToBack) {
      _deck.add(
        _Entry<T>(entry.item, entry.itemKey)
          ..hostKey = _RevKey(entry.itemKey, ++_revision),
      );
    } else {
      _dismissed.add(entry.itemKey);
    }
    if (widget.historyLimit > 0) {
      _history.add(
        _Record<T>(
          entry: entry,
          direction: direction,
          outcome: outcome,
          endPose: move.finalPose,
        ),
      );
      if (_history.length > widget.historyLimit) _history.removeAt(0);
    }

    // The cards behind carry on from where the drag left them.
    final p = _pFromPose ? _motion.p : 0.0;
    _tilt = 1;
    _pFromPose = true;
    _topMove = null;
    _motion.pose = SwipePose.identity;
    _motion.progress = SwipeProgress.zero;
    _motion.p = 0;
    _controller.progressNotifier.value = SwipeProgress.zero;
    _startPromotion(_s + 1 - p);

    _publishCounts();
    _startTicker();
    setState(() {});

    behavior.onCommit?.call(event);
    widget.onSwipe?.call(event);

    if (leavesDeck) {
      if (_deck.isEmpty) {
        if (!_endSent) {
          _endSent = true;
          widget.onEnd?.call();
        }
      } else if (_deck.length <= widget.needMoreThreshold && !_needMoreSent) {
        _needMoreSent = true;
        widget.onNeedMore?.call(_deck.length);
      }
    }
  }

  SwipeMove _exitMove(
    SwipeGeometry geometry,
    SwipeDirection direction,
    SwipePose start,
    Offset velocity,
  ) {
    final exit = geometry.exitTarget(direction, start.offset, velocity);
    final gone = geometry.exitDistance(direction) - geometry.exitMargin * 0.5;
    return SpringMove(
      from: start.offset,
      velocity: velocity,
      to: exit,
      spring: widget.physics.fling.description,
      rotationFor: _rotationFor,
      isOut: (o) => direction.distance(o) >= gone,
    );
  }

  SwipeEvent<T> _eventFor(
    _Entry<T> entry,
    SwipeDirection direction,
    SwipeOutcome outcome,
    Offset velocity,
    bool programmatic,
    int remaining,
  ) {
    return SwipeEvent<T>(
      item: entry.item,
      key: entry.itemKey,
      direction: direction,
      outcome: outcome,
      velocity: velocity,
      programmatic: programmatic,
      remaining: remaining,
    );
  }

  // ---- SwipeHandle --------------------------------------------------------

  @override
  void swipe(SwipeDirection direction, Offset? velocity) {
    if (_deck.isEmpty || _geometry == null || _pointerDown) return;
    final behavior = _behaviors[direction];
    if (behavior == null) return;
    if (behavior.guard?.call(_deck.first.item) == false) return;
    _enablePFromPose();
    _topMove = null;
    _tilt = 1;
    final speed =
        behavior.outcome == SwipeOutcome.springBack
            ? widget.physics.triggerKick
            : widget.physics.programmaticSpeed;
    _commit(
      direction,
      velocity: velocity ?? direction.vector * speed,
      programmatic: true,
    );
  }

  @override
  void undo() {
    if (_history.isEmpty || _pointerDown || _geometry == null) return;
    final record = _history.removeLast();
    final entry = record.entry;

    // Bring the card back from wherever it is: still flying, or already gone.
    var start = record.endPose;
    final alive = _leavers.indexWhere((l) => identical(l.entry, entry));
    if (alive >= 0) {
      final leaver = _leavers.removeAt(alive);
      start = leaver.pose.pose;
      final notifier = leaver.pose;
      WidgetsBinding.instance.addPostFrameCallback((_) => notifier.dispose());
      if (leaver.outcome == SwipeOutcome.consume) {
        _controller.consumingNotifier.value = null;
      }
    }

    if (record.outcome == SwipeOutcome.sendToBack) {
      _deck.removeWhere(
        (e) => e.itemKey == entry.itemKey && !identical(e, entry),
      );
    } else {
      _dismissed.remove(entry.itemKey);
    }
    final p = _pFromPose ? _motion.p : 0.0;
    _deck.insert(0, entry);
    _endSent = false;

    // Cards shift back a place; the promotion animates it, and the returning
    // card does not also count as "dragged".
    _pFromPose = false;
    _tilt = 1;
    _motion.pose = start;
    _motion.progress = SwipeProgress.zero;
    _motion.p = 0;
    _controller.progressNotifier.value = SwipeProgress.zero;
    _startPromotion(_s - 1 - p);
    _startTopMove(
      SpringMove(
        from: start.offset,
        velocity: Offset.zero,
        to: Offset.zero,
        spring: widget.physics.undo.description,
        rotationFor: _rotationFor,
        fromScale: start.scale,
        fromOpacity: start.opacity,
      ),
    );

    _publishCounts();
    setState(() {});
    widget.onUndo?.call(
      _eventFor(
        entry,
        record.direction,
        record.outcome,
        Offset.zero,
        true,
        _deck.length,
      ),
    );
  }

  @override
  void reset() {
    for (final leaver in _leavers) {
      final notifier = leaver.pose;
      WidgetsBinding.instance.addPostFrameCallback((_) => notifier.dispose());
    }
    _leavers.clear();
    _history.clear();
    _dismissed.clear();
    _preloaded.clear();
    _topMove = null;
    _sMove = null;
    _s = 0;
    _pFromPose = true;
    _pointerDown = false;
    _dragStarted = false;
    _tilt = 1;
    _needMoreSent = false;
    _endSent = false;
    _motion
      ..pose = SwipePose.identity
      ..progress = SwipeProgress.zero
      ..p = 0
      ..s = 0;
    _controller.progressNotifier.value = SwipeProgress.zero;
    _controller.consumingNotifier.value = null;
    _syncItems(initial: true);
    _publishCounts();
    _motion.changed();
    setState(() {});
  }

  // ---- building -----------------------------------------------------------

  void _schedulePreload() {
    if (widget.onPreload == null || _preloadScheduled) return;
    _preloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadScheduled = false;
      if (!mounted) return;
      final limit = math.min(
        _deck.length,
        widget.layout.visibleCards + 1 + widget.preloadCount,
      );
      for (var k = 0; k < limit; k++) {
        final entry = _deck[k];
        if (_preloaded.add(entry.itemKey)) {
          widget.onPreload!(context, entry.item, k);
        }
      }
    });
  }

  Matrix4 _matrix(SwipePose drag, SwipeSlot slot, Size size) {
    final m = Matrix4.translationValues(drag.offset.dx, drag.offset.dy, 0);
    if (drag.rotation != 0) m.multiply(Matrix4.rotationZ(drag.rotation));
    if (drag.scale != 1) {
      m.multiply(Matrix4.diagonal3Values(drag.scale, drag.scale, 1));
    }
    final ax = slot.alignment.x * size.width / 2;
    final ay = slot.alignment.y * size.height / 2;
    m.multiply(
      Matrix4.translationValues(slot.offset.dx + ax, slot.offset.dy + ay, 0),
    );
    if (slot.rotation != 0) m.multiply(Matrix4.rotationZ(slot.rotation));
    if (slot.scale != 1) {
      m.multiply(Matrix4.diagonal3Values(slot.scale, slot.scale, 1));
    }
    m.multiply(Matrix4.translationValues(-ax, -ay, 0));
    return m;
  }

  Widget _place({
    required Widget child,
    required SwipePose pose,
    required SwipeSlot slot,
    required Size size,
  }) {
    return Transform(
      transform: _matrix(pose, slot, size),
      alignment: Alignment.center,
      // Always an Opacity, even at 1: swapping the widget type would rebuild
      // the card's subtree. At full opacity it adds no layer.
      child: Opacity(
        opacity: (pose.opacity * slot.opacity).clamp(0.0, 1.0),
        child: child,
      ),
    );
  }

  Widget _content(
    BuildContext context,
    _Entry<T> entry,
    int depth, {
    bool leaving = false,
  }) {
    return RepaintBoundary(
      child: widget.itemBuilder(
        context,
        entry.item,
        SwipeCardInfo(
          depth: depth,
          isTop: depth == 0 && !leaving,
          isLeaving: leaving,
          progress: _controller.progress,
        ),
      ),
    );
  }

  Widget _buildBack(BuildContext context, _Entry<T> entry, int k, Rect rect) {
    final content = IgnorePointer(child: _content(context, entry, k));
    return Positioned.fromRect(
      key: entry.hostKey,
      rect: rect,
      child: AnimatedBuilder(
        animation: _motion,
        child: content,
        builder: (context, child) {
          final depth = math.max(0.0, k + _motion.s - _motion.p);
          return _place(
            child: child!,
            pose: SwipePose.identity,
            slot: widget.layout.slotAt(depth),
            size: rect.size,
          );
        },
      ),
    );
  }

  Widget _buildLeaver(BuildContext context, _Leaver<T> leaver, Rect rect) {
    final content = IgnorePointer(
      child: _content(context, leaver.entry, 0, leaving: true),
    );
    return Positioned.fromRect(
      key: leaver.entry.hostKey,
      rect: rect,
      child: AnimatedBuilder(
        animation: leaver.pose,
        child: content,
        builder:
            (context, child) => _place(
              child: child!,
              pose: leaver.pose.pose,
              slot: widget.layout.slotAt(0),
              size: rect.size,
            ),
      ),
    );
  }

  Widget _buildTop(BuildContext context, _Entry<T> entry, Rect rect) {
    final overlay = widget.overlayBuilder;
    Widget card = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _content(context, entry, 0),
        if (overlay != null)
          AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final progress = _motion.progress;
              if (!progress.isActive) return const SizedBox.shrink();
              return IgnorePointer(child: overlay(context, progress));
            },
          ),
      ],
    );

    if (widget.enabled) {
      card = RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          PanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                () => PanGestureRecognizer(debugOwner: this),
                (recognizer) {
                  recognizer
                    // Count the movement from the moment of touch, so the card
                    // stays under the finger instead of lagging by the slop.
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onStart = _onDragStart
                    ..onUpdate = _onDragUpdate
                    ..onEnd = _onDragEnd
                    ..onCancel = _onDragCancel;
                },
              ),
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: card,
        ),
      );
    }

    final label = widget.directionLabel ?? _defaultLabel;
    card = Semantics(
      container: true,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        for (final d in _open)
          CustomSemanticsAction(label: label(d)): () => swipe(d, null),
      },
      child: card,
    );

    return Positioned.fromRect(
      key: entry.hostKey,
      rect: rect,
      child: AnimatedBuilder(
        animation: _motion,
        child: card,
        builder:
            (context, child) => _place(
              child: child!,
              pose: _motion.pose,
              slot: widget.layout.slotAt(math.max(0.0, _motion.s)),
              size: rect.size,
            ),
      ),
    );
  }

  static String _defaultLabel(SwipeDirection d) => 'Swipe ${d.name}';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedWidth && constraints.hasBoundedHeight,
          'SwipeCardStack needs bounded width and height. Wrap it in a '
          'SizedBox or Expanded.',
        );
        final size = constraints.biggest;
        final geometry = SwipeGeometry.forStack(size, widget.layout.reserve);
        _geometry = geometry;
        final rect = geometry.cardRect;

        final built = math.min(_deck.length, widget.layout.visibleCards + 1);
        final children = <Widget>[
          if (_deck.isEmpty && widget.emptyBuilder != null)
            Positioned.fill(child: widget.emptyBuilder!(context)),
          for (var k = built - 1; k >= 1; k--)
            _buildBack(context, _deck[k], k, rect),
          if (_deck.isNotEmpty) _buildTop(context, _deck.first, rect),
          for (final leaver in _leavers) _buildLeaver(context, leaver, rect),
        ];

        _schedulePreload();

        Widget stack = Stack(clipBehavior: Clip.none, children: children);
        if (widget.enableKeyboard) {
          stack = CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              for (final d in _open)
                SingleActivator(_keyFor(d)): () => swipe(d, null),
            },
            child: Focus(autofocus: widget.autofocus, child: stack),
          );
        }
        return stack;
      },
    );
  }

  static LogicalKeyboardKey _keyFor(SwipeDirection d) => switch (d) {
    SwipeDirection.left => LogicalKeyboardKey.arrowLeft,
    SwipeDirection.right => LogicalKeyboardKey.arrowRight,
    SwipeDirection.up => LogicalKeyboardKey.arrowUp,
    SwipeDirection.down => LogicalKeyboardKey.arrowDown,
  };
}
