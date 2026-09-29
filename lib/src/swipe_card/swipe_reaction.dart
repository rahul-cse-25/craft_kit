import 'package:flutter/widgets.dart';

import 'swipe_card_controller.dart';
import 'swipe_direction.dart';
import 'swipe_progress.dart';

/// How a card is interacting with a direction's target right now.
@immutable
class SwipeReactionState {
  /// Creates the state.
  const SwipeReactionState({required this.approach, required this.arrival});

  /// 0 to 1: how far the card is dragged toward this direction.
  final double approach;

  /// 0 to 1: how far a card is on its way into this direction's target. It
  /// eases back to 0 shortly after the card arrives.
  final double arrival;
}

/// Builds the widget for a [SwipeReactionState].
typedef SwipeReactionBuilder =
    Widget Function(
      BuildContext context,
      SwipeReactionState state,
      Widget? child,
    );

/// Lets a widget (usually the button a card is consumed into) react to a card
/// approaching and arriving.
///
/// ```dart
/// SwipeReaction(
///   controller: controller,
///   direction: SwipeDirection.right,
///   builder: (context, s, child) => Transform.scale(
///     scale: 1 + 0.2 * s.approach + 0.3 * s.arrival,
///     child: child,
///   ),
///   child: likeButton,
/// )
/// ```
///
/// Only the builder output is rebuilt as the card moves; [child] is not.
class SwipeReaction extends StatefulWidget {
  /// Creates the widget.
  const SwipeReaction({
    super.key,
    required this.controller,
    required this.direction,
    required this.builder,
    this.child,
    this.releaseDuration = const Duration(milliseconds: 320),
  });

  /// The stack's controller.
  final SwipeCardController controller;

  /// The direction whose card this widget reacts to.
  final SwipeDirection direction;

  /// Builds the reacting widget.
  final SwipeReactionBuilder builder;

  /// A subtree that does not depend on the reaction.
  final Widget? child;

  /// How long [SwipeReactionState.arrival] takes to ease back to 0 after the
  /// card arrives.
  final Duration releaseDuration;

  @override
  State<SwipeReaction> createState() => _SwipeReactionState();
}

class _SwipeReactionState extends State<SwipeReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _release;
  double _arrival = 0;
  double _releaseFrom = 0;

  @override
  void initState() {
    super.initState();
    _release = AnimationController(
      vsync: this,
      duration: widget.releaseDuration,
    );
    widget.controller.consuming.addListener(_onConsuming);
  }

  @override
  void didUpdateWidget(SwipeReaction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.consuming.removeListener(_onConsuming);
      widget.controller.consuming.addListener(_onConsuming);
    }
    _release.duration = widget.releaseDuration;
  }

  @override
  void dispose() {
    widget.controller.consuming.removeListener(_onConsuming);
    _release.dispose();
    super.dispose();
  }

  void _onConsuming() {
    final consume = widget.controller.consuming.value;
    if (consume != null && consume.direction == widget.direction) {
      _release.stop();
      _arrival = consume.progress;
    } else if (_arrival > 0 && !_release.isAnimating) {
      _releaseFrom = _arrival;
      _arrival = 0;
      _release.forward(from: 0);
    }
  }

  double get _arrivalNow {
    if (_release.isAnimating) {
      return _releaseFrom * (1 - Curves.easeOut.transform(_release.value));
    }
    return _arrival;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.controller.progress,
        widget.controller.consuming,
        _release,
      ]),
      child: widget.child,
      builder: (context, child) {
        final SwipeProgress progress = widget.controller.progress.value;
        return widget.builder(
          context,
          SwipeReactionState(
            approach: progress[widget.direction],
            arrival: _arrivalNow,
          ),
          child,
        );
      },
    );
  }
}
