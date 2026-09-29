import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'swipe_card_controller.dart';
import 'swipe_direction.dart';

/// Builds the card for [item] at [index] in the source list.
typedef SwipeCardBuilder<T> =
    Widget Function(BuildContext context, T item, int index);

/// Builds an overlay (for example a "LIKE" or "NOPE" stamp) drawn over the top
/// card while it is dragged. [progress] goes from 0 to 1 as the card nears the
/// swipe threshold in [direction].
typedef SwipeOverlayBuilder =
    Widget Function(
      BuildContext context,
      SwipeDirection direction,
      double progress,
    );

/// Called after a card has been swiped away.
typedef SwipeCallback<T> =
    void Function(T item, int index, SwipeDirection direction);

/// A stack of cards the user can swipe away, Tinder style.
///
/// The stack fills the space it is given; each card is laid out at that size.
class SwipeCardStack<T> extends StatefulWidget {
  /// Creates a swipeable stack.
  const SwipeCardStack({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.controller,
    this.onSwipe,
    this.onEnd,
    this.overlayBuilder,
    this.emptyBuilder,
    this.allowedDirections = const <SwipeDirection>{
      SwipeDirection.left,
      SwipeDirection.right,
    },
    this.visibleCards = 3,
    this.threshold = 0.3,
    this.maxAngle = 0.25,
    this.duration = const Duration(milliseconds: 280),
  }) : assert(visibleCards > 0, 'visibleCards must be positive'),
       assert(threshold > 0 && threshold <= 1, 'threshold must be in (0, 1]');

  /// Cards, top first.
  final List<T> items;

  /// Builds one card.
  final SwipeCardBuilder<T> itemBuilder;

  /// Optional controller for programmatic swipe and undo.
  final SwipeCardController? controller;

  /// Called after each swipe.
  final SwipeCallback<T>? onSwipe;

  /// Called when the last card has been swiped away.
  final VoidCallback? onEnd;

  /// Optional overlay drawn on the top card while dragging.
  final SwipeOverlayBuilder? overlayBuilder;

  /// Shown once every card has been swiped.
  final WidgetBuilder? emptyBuilder;

  /// Directions that count as a swipe. Other drags snap back.
  final Set<SwipeDirection> allowedDirections;

  /// How many cards to render at once (top card included).
  final int visibleCards;

  /// Fraction of the stack's width (or height for up/down) the card must be
  /// dragged to count as a swipe. A fast fling also counts.
  final double threshold;

  /// Maximum tilt in radians at the edge of the screen.
  final double maxAngle;

  /// Length of the fly-away and snap-back animations.
  final Duration duration;

  @override
  State<SwipeCardStack<T>> createState() => _SwipeCardStackState<T>();
}

class _SwipeCardStackState<T> extends State<SwipeCardStack<T>>
    with SingleTickerProviderStateMixin {
  static const double _flingVelocity = 900;

  late final AnimationController _anim = AnimationController(vsync: this);
  final List<({SwipeDirection direction, Offset exit})> _history = [];

  int _index = 0;
  Offset _offset = Offset.zero;
  Size _size = Size.zero;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(SwipeCardStack<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      _attach();
    }
    if (oldWidget.items != widget.items) {
      _index = 0;
      _offset = Offset.zero;
      _history.clear();
    }
  }

  void _attach() {
    widget.controller?.attach(
      swipe: _programmaticSwipe,
      undo: _undo,
      canUndo: () => _history.isNotEmpty && !_busy,
    );
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _anim.dispose();
    super.dispose();
  }

  bool get _hasCard => _index < widget.items.length;

  Offset _exitFor(SwipeDirection d, Offset from) => switch (d) {
    SwipeDirection.left => Offset(-_size.width * 1.6, from.dy),
    SwipeDirection.right => Offset(_size.width * 1.6, from.dy),
    SwipeDirection.up => Offset(from.dx, -_size.height * 1.6),
    SwipeDirection.down => Offset(from.dx, _size.height * 1.6),
  };

  SwipeDirection _directionOf(Offset o) {
    if (o.dx.abs() >= o.dy.abs()) {
      return o.dx >= 0 ? SwipeDirection.right : SwipeDirection.left;
    }
    return o.dy >= 0 ? SwipeDirection.down : SwipeDirection.up;
  }

  double _distanceIn(SwipeDirection d, Offset o) => switch (d) {
    SwipeDirection.left => -o.dx,
    SwipeDirection.right => o.dx,
    SwipeDirection.up => -o.dy,
    SwipeDirection.down => o.dy,
  };

  double _extent(SwipeDirection d) =>
      (d == SwipeDirection.left || d == SwipeDirection.right)
      ? _size.width
      : _size.height;

  double _progress() {
    if (_offset == Offset.zero || _size.isEmpty) return 0;
    final d = _directionOf(_offset);
    if (!widget.allowedDirections.contains(d)) return 0;
    final p = _distanceIn(d, _offset) / (_extent(d) * widget.threshold);
    return p.clamp(0.0, 1.0);
  }

  void _animateTo(Offset target, {required VoidCallback onDone}) {
    final tween = Tween<Offset>(begin: _offset, end: target);
    _busy = true;
    _anim
      ..duration = widget.duration
      ..reset();
    void listener() {
      setState(() {
        _offset = tween.transform(Curves.easeOut.transform(_anim.value));
      });
    }

    _anim.addListener(listener);
    _anim.forward().whenComplete(() {
      _anim.removeListener(listener);
      _busy = false;
      if (mounted) onDone();
    });
  }

  void _commitSwipe(SwipeDirection direction) {
    final item = widget.items[_index];
    final index = _index;
    final exit = _exitFor(direction, _offset);
    _animateTo(
      exit,
      onDone: () {
        setState(() {
          _history.add((direction: direction, exit: exit));
          _index++;
          _offset = Offset.zero;
        });
        widget.onSwipe?.call(item, index, direction);
        if (!_hasCard) widget.onEnd?.call();
      },
    );
  }

  void _programmaticSwipe(SwipeDirection direction) {
    if (_busy || !_hasCard || _size.isEmpty) return;
    if (!widget.allowedDirections.contains(direction)) return;
    _commitSwipe(direction);
  }

  void _undo() {
    if (_busy || _history.isEmpty) return;
    final last = _history.removeLast();
    setState(() {
      _index--;
      _offset = last.exit;
    });
    _animateTo(Offset.zero, onDone: () {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_busy) return;
    setState(() => _offset += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_busy) return;
    final direction = _directionOf(_offset);
    final allowed = widget.allowedDirections.contains(direction);
    final v = details.velocity.pixelsPerSecond;
    final flung =
        allowed &&
        (direction == SwipeDirection.left || direction == SwipeDirection.right
                ? v.dx.abs()
                : v.dy.abs()) >
            _flingVelocity &&
        _distanceIn(direction, v) > 0;
    final passed =
        allowed &&
        _distanceIn(direction, _offset) >=
            _extent(direction) * widget.threshold;
    if (passed || flung) {
      _commitSwipe(direction);
    } else {
      _animateTo(Offset.zero, onDone: () {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        if (!_hasCard) {
          return widget.emptyBuilder?.call(context) ?? const SizedBox.shrink();
        }
        final progress = _progress();
        final visible = math.min(
          widget.visibleCards,
          widget.items.length - _index,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            for (var depth = visible - 1; depth >= 1; depth--)
              _buildBackCard(context, depth, progress),
            _buildTopCard(context, progress),
          ],
        );
      },
    );
  }

  Widget _buildBackCard(BuildContext context, int depth, double progress) {
    // As the top card leaves, cards behind move up toward the next slot.
    final t = (depth - progress).clamp(0.0, depth.toDouble());
    final index = _index + depth;
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, 12.0 * t),
        child: Transform.scale(
          scale: 1 - 0.05 * t,
          child: IgnorePointer(
            child: widget.itemBuilder(context, widget.items[index], index),
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard(BuildContext context, double progress) {
    final item = widget.items[_index];
    final angle = _size.width == 0
        ? 0.0
        : (_offset.dx / _size.width).clamp(-1.0, 1.0) * widget.maxAngle;
    final overlay = widget.overlayBuilder;
    return Positioned.fill(
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Transform.translate(
          offset: _offset,
          child: Transform.rotate(
            angle: angle,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                widget.itemBuilder(context, item, _index),
                if (overlay != null && progress > 0)
                  IgnorePointer(
                    child: overlay(context, _directionOf(_offset), progress),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
