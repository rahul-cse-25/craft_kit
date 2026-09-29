part of 'swipe_card_stack.dart';

/// Pointer handling and the release of a drag: judging it, then committing
/// the swipe or springing the card back.
extension _StackGestures<T> on _SwipeCardStackState<T> {
  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || _deck.isEmpty || _geometry == null) return;
    if (_deck.first.genieIn != null) return;
    if (_pointerDown) return;
    _pointerDown = true;
    _dragStarted = false;
    _rewindLeft = 0; // touching the card ends a rewind
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
      SwipePose(offset: offset, rotation: _rotationWith(offset, _tilt)),
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
    final tilt = _tilt;
    _startTopMove(
      SpringMove(
        from: _motion.pose.offset,
        velocity: velocity,
        to: Offset.zero,
        spring: widget.physics.settle.description,
        rotationFor: (o) => _rotationWith(o, tilt),
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
    // This card's own tilt, captured now: the next card may be grabbed with a
    // different one before this card has finished leaving.
    final tilt = _tilt;
    double rotationFor(Offset o) => _rotationWith(o, tilt);
    _haptic(widget.haptics.commit);

    var outcome = behavior.outcome;

    // ---- a trigger or an undo: the card stays and springs back ----
    if (outcome == SwipeOutcome.springBack || outcome == SwipeOutcome.undo) {
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
          rotationFor: rotationFor,
        ),
      );
      behavior.onCommit?.call(event);
      widget.onSwipe?.call(event);
      if (outcome == SwipeOutcome.undo) _undoOne();
      return;
    }

    // ---- the card leaves: build its move ----
    SwipeMove move;
    _GenieRun? genie;
    SwipeTarget? consumed;
    Rect? consumedRect;
    if (outcome == SwipeOutcome.consume) {
      final target = behavior.target!;
      final global = target.resolveRect();
      final box = context.findRenderObject();
      if (global != null && box is RenderBox && box.attached) {
        final local = Rect.fromPoints(
          box.globalToLocal(global.topLeft),
          box.globalToLocal(global.bottomRight),
        );
        final point = _pointIn(local, target.alignment);
        final to = point - geometry.cardRect.center;
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
        consumed = target;
        consumedRect = local;
        if (target.effect == SwipeConsumeEffect.genie) {
          final image = _snapshot(entry);
          if (image != null) {
            final slot = widget.layout.slotAt(math.max(0.0, _motion.s));
            genie = _GenieRun(
              image: image,
              quad: _cornersOf(
                geometry.cardRect,
                _stackMatrix(geometry.cardRect, start, slot),
              ),
              target: point,
              lag: target.genieLag,
            );
          }
        }
      } else {
        // The target is not on screen: fall back to leaving.
        outcome = SwipeOutcome.dismiss;
        move = _exitMove(geometry, direction, start, velocity, rotationFor);
      }
    } else {
      move = _exitMove(geometry, direction, start, velocity, rotationFor);
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

    _Record<T>? record;
    if (widget.historyLimit > 0) {
      record = _Record<T>(
        entry: entry,
        direction: direction,
        outcome: outcome,
        endPose: move.finalPose,
        tilt: tilt,
        target: consumed,
        targetRect: consumedRect,
      );
      _history.add(record);
      if (_history.length > widget.historyLimit) {
        _disposeImage(_history.removeAt(0).image);
      }
    }

    // The card becomes a leaver with its own pose, above the deck.
    final leaver = _Leaver<T>(
      entry: entry,
      move: move,
      direction: direction,
      outcome: outcome,
      behavior: behavior,
      event: event,
      pose: start,
      slot: widget.layout.slotAt(math.max(0.0, _motion.s)),
      start: _newStart,
      genie: genie,
      record: record,
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
    // If the next card was still arriving, it carries on as the top card.
    _adoptArrivalAsTop();

    _publishCounts();
    _startTicker();
    // ignore: invalid_use_of_protected_member
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
    double Function(Offset) rotationFor,
  ) {
    final exit = geometry.exitTarget(direction, start.offset, velocity);
    final gone = geometry.exitDistance(direction) - geometry.exitMargin * 0.5;
    return SpringMove(
      from: start.offset,
      velocity: velocity,
      to: exit,
      spring: widget.physics.fling.description,
      rotationFor: rotationFor,
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

  Offset _pointIn(Rect rect, Alignment alignment) => Offset(
    rect.center.dx + alignment.x * rect.width / 2,
    rect.center.dy + alignment.y * rect.height / 2,
  );

  /// A picture of the card as it is now, or null if it cannot be captured.
  ui.Image? _snapshot(_Entry<T> entry) {
    final render = entry.boundaryKey.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary || !render.hasSize) return null;
    try {
      if (render.debugNeedsPaint) return null;
      final ratio = math.min(MediaQuery.devicePixelRatioOf(context), 2.0);
      final image = render.toImageSync(pixelRatio: ratio);
      debugLiveGenieImages++;
      return image;
    } on Object {
      return null;
    }
  }
}
