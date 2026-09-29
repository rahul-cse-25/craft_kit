part of 'swipe_card_stack.dart';

/// Building the widgets of a stack: the card transforms, the cached card
/// content, and the genie layers.
extension _StackBuilding<T> on _SwipeCardStackState<T> {
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

  /// The card-local transform of [drag] and [slot], about the card's centre.
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

  /// [_matrix] expressed in stack coordinates, for painting.
  Matrix4 _stackMatrix(Rect rect, SwipePose pose, SwipeSlot slot) {
    final c = rect.center;
    return Matrix4.translationValues(c.dx, c.dy, 0)
      ..multiply(_matrix(pose, slot, rect.size))
      ..multiply(Matrix4.translationValues(-c.dx, -c.dy, 0));
  }

  /// The four corners of [rect] (top left, top right, bottom right, bottom
  /// left) after [m].
  List<Offset> _cornersOf(Rect rect, Matrix4 m) => <Offset>[
    for (final corner in <Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ])
      MatrixUtils.transformPoint(m, corner),
  ];

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

  /// The card's widget. The same instance is reused while nothing about the
  /// card changed, so Flutter does not rebuild it when the stack merely
  /// changes state (a card finished leaving, an arrival ended).
  Widget _content(
    BuildContext context,
    _Entry<T> entry,
    int depth, {
    bool leaving = false,
  }) {
    final cached = _cache[entry.hostKey];
    if (cached != null &&
        identical(cached.item, entry.item) &&
        cached.depth == depth &&
        cached.leaving == leaving) {
      return cached.widget;
    }
    final built = widget.itemBuilder(
      context,
      entry.item,
      SwipeCardInfo(
        depth: depth,
        isTop: depth == 0 && !leaving,
        isLeaving: leaving,
        progress: _controller.progress,
      ),
    );
    _cache[entry.hostKey] = _Cached(entry.item, depth, leaving, built);
    return built;
  }

  Map<Type, GestureRecognizerFactory> get _gestures =>
      <Type, GestureRecognizerFactory>{
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
      };

  /// One card, in whatever role it has right now (top, behind, leaving).
  ///
  /// Every role builds the same widget structure, so a card keeps its state
  /// (and is not rebuilt from scratch) as it moves from the back of the stack
  /// to the top and out.
  Widget _buildCard(
    BuildContext context,
    _Entry<T> entry,
    int k,
    Rect rect, {
    _Leaver<T>? leaver,
  }) {
    final isTop = leaver == null && k == 0;
    final overlay = widget.overlayBuilder;
    final label = widget.directionLabel ?? _SwipeCardStackState._defaultLabel;

    final Widget card = IgnorePointer(
      ignoring: !isTop,
      child: ExcludeSemantics(
        excluding: !isTop,
        child: Semantics(
          container: isTop,
          customSemanticsActions:
              isTop
                  ? <CustomSemanticsAction, VoidCallback>{
                    for (final d in _open)
                      CustomSemanticsAction(label: label(d)):
                          () => swipe(d, null),
                  }
                  : const <CustomSemanticsAction, VoidCallback>{},
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures:
                isTop && widget.enabled
                    ? _gestures
                    : const <Type, GestureRecognizerFactory>{},
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: isTop ? _onPointerDown : null,
              onPointerUp: isTop ? _onPointerUp : null,
              onPointerCancel: isTop ? _onPointerCancel : null,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  RepaintBoundary(
                    key: entry.boundaryKey,
                    child: _content(
                      context,
                      entry,
                      leaver != null ? 0 : k,
                      leaving: leaver != null,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _motion,
                    builder: (context, _) {
                      if (!isTop || overlay == null) {
                        return const SizedBox.shrink();
                      }
                      final progress = _motion.progress;
                      if (!progress.isActive) return const SizedBox.shrink();
                      return IgnorePointer(child: overlay(context, progress));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final arrival = entry.arrival;
    final Listenable animation =
        leaver != null
            ? leaver.pose
            : arrival != null
            ? Listenable.merge(<Listenable>[_motion, arrival.pose])
            : _motion;

    return Positioned.fromRect(
      key: entry.hostKey,
      rect: rect,
      child: AnimatedBuilder(
        animation: animation,
        child: card,
        builder: (context, child) {
          final SwipePose pose;
          final SwipeSlot slot;
          if (leaver != null) {
            pose = leaver.pose.pose;
            slot = leaver.slot;
          } else if (isTop) {
            pose = _motion.pose;
            slot = widget.layout.slotAt(math.max(0.0, _motion.s));
          } else {
            pose = arrival?.pose.pose ?? SwipePose.identity;
            slot = widget.layout.slotAt(
              math.max(0.0, k + _motion.s - _motion.p),
            );
          }
          return _place(child: child!, pose: pose, slot: slot, size: rect.size);
        },
      ),
    );
  }

  /// A card that is being consumed with the genie: drawn from its picture.
  Widget _buildGenieLeaver(_Leaver<T> leaver) {
    final run = leaver.genie!;
    return Positioned.fill(
      key: leaver.entry.hostKey,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(painter: _GeniePainter(run: run)),
        ),
      ),
    );
  }

  /// A card pouring back out of a button. It follows its place in the deck, so
  /// it lands in the right slot even while other cards arrive above it.
  Widget _buildGenieIn(_Entry<T> entry, int k, Rect rect) {
    final run = entry.genieIn!;
    return Positioned.fill(
      key: entry.hostKey,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(
            painter: _GeniePainter(
              run: run,
              repaint: Listenable.merge(<Listenable>[run.progress, _motion]),
              slot: () {
                final depth =
                    k == 0
                        ? math.max(0.0, _motion.s)
                        : math.max(0.0, k + _motion.s - _motion.p);
                return _stackMatrix(
                  rect,
                  SwipePose.identity,
                  widget.layout.slotAt(depth),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
