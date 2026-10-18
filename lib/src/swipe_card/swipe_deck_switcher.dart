import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'swipe_direction.dart';
import 'swipe_physics.dart';

/// How a [SwipeDeckSwitcher] replaces one deck with the next.
enum SwipeDeckTransition {
  /// The old deck is thrown off toward a direction while the new one is dealt
  /// in from below on a spring. For a deck that is replaced by a different
  /// set of cards.
  deal,

  /// The deck turns about its vertical axis; the cards change while it is
  /// edge-on, so the swap itself is never seen, and it settles on a spring.
  /// For a refinement of the same deck.
  flip,

  /// A short cross-fade. Also used for every transition when the platform
  /// asks for reduced motion.
  fade,

  /// The new deck replaces the old one at once.
  none,
}

/// Replaces a whole deck (usually a `SwipeCardStack`) with an animation when
/// [deckKey] changes.
///
/// The outgoing deck is frozen as a picture the moment the key changes, so it
/// leaves exactly as it looked, even if the data behind it already changed.
/// The incoming deck is live and fully interactive once it has landed.
///
/// While [deckKey] stays the same, [child] simply rebuilds in place and keeps
/// its state.
class SwipeDeckSwitcher extends StatefulWidget {
  /// Creates a deck switcher.
  const SwipeDeckSwitcher({
    super.key,
    required this.deckKey,
    required this.child,
    this.transition = SwipeDeckTransition.deal,
    this.throwDirection = SwipeDirection.left,
    this.spring = const SwipeSpring(stiffness: 240, dampingRatio: 0.74),
    this.exitDuration = const Duration(milliseconds: 280),
    this.haptics = true,
    this.onSettled,
  });

  /// Identifies the deck. A different value starts a [transition].
  final Object deckKey;

  /// The deck.
  final Widget child;

  /// How the next change of [deckKey] is animated. Read when the key changes,
  /// so a parent can choose it per change.
  final SwipeDeckTransition transition;

  /// Where a [SwipeDeckTransition.deal] throws the old deck.
  final SwipeDirection throwDirection;

  /// The spring the new deck settles with. Below 1 damping overshoots a
  /// little, which reads as a natural landing.
  final SwipeSpring spring;

  /// How long the old deck takes to leave.
  final Duration exitDuration;

  /// Whether a light tap is felt when the new deck lands.
  final bool haptics;

  /// Called when a transition has finished.
  final VoidCallback? onSettled;

  @override
  State<SwipeDeckSwitcher> createState() => _SwipeDeckSwitcherState();
}

class _SwipeDeckSwitcherState extends State<SwipeDeckSwitcher>
    with TickerProviderStateMixin {
  static const Duration _fadeDuration = Duration(milliseconds: 160);

  final GlobalKey _boundary = GlobalKey();
  late final AnimationController _exit = AnimationController(vsync: this);
  late final AnimationController _enter = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  ui.Image? _outgoing;
  SwipeDeckTransition _active = SwipeDeckTransition.none;
  bool _reduceMotion = false;
  int _run = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void didUpdateWidget(SwipeDeckSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deckKey == widget.deckKey) return;
    var transition = widget.transition;
    if (_reduceMotion && transition != SwipeDeckTransition.none) {
      transition = SwipeDeckTransition.fade;
    }
    _start(transition);
  }

  void _start(SwipeDeckTransition transition) {
    final run = ++_run;
    _replaceOutgoing(
      transition == SwipeDeckTransition.none ? null : _capture(),
    );
    _active = transition;
    _exit.stop();
    _enter.stop();
    switch (transition) {
      case SwipeDeckTransition.none:
        _exit.value = 1;
        _enter.value = 1;
        _settled(run);
      case SwipeDeckTransition.fade:
        _exit.value = 0;
        _enter.value = 0;
        _exit.duration = _fadeDuration;
        _exit.forward().whenCompleteOrCancel(() => _finishExit(run));
        _enter
            .animateTo(1, duration: _fadeDuration, curve: Curves.easeOut)
            .whenCompleteOrCancel(() => _settled(run));
      case SwipeDeckTransition.deal:
        _exit.value = 0;
        _enter.value = 0;
        _exit.duration = widget.exitDuration;
        // The new deck starts rising while the old one is still leaving, so
        // the hand-off reads as one motion.
        var dealt = false;
        void dealWhenReady() {
          if (dealt || _exit.value < 0.3) return;
          dealt = true;
          _exit.removeListener(dealWhenReady);
          if (!mounted || run != _run) return;
          if (widget.haptics) HapticFeedback.lightImpact();
          _springIn(run);
        }

        _exit.addListener(dealWhenReady);
        _exit.forward().whenCompleteOrCancel(() {
          _exit.removeListener(dealWhenReady);
          // Interrupted before the hand-off: still bring the deck in.
          if (!dealt && mounted && run == _run) {
            dealt = true;
            _springIn(run);
          }
          _finishExit(run);
        });
      case SwipeDeckTransition.flip:
        _exit.value = 0;
        _enter.value = 0;
        _exit.duration = widget.exitDuration * 0.6;
        _exit.forward().whenCompleteOrCancel(() {
          _finishExit(run);
          if (!mounted || run != _run) return;
          if (widget.haptics) HapticFeedback.selectionClick();
          _springIn(run);
        });
    }
    setState(() {});
  }

  void _springIn(int run) {
    final simulation = SpringSimulation(
      widget.spring.description,
      _enter.value,
      1,
      0,
    );
    _enter.animateWith(simulation).whenCompleteOrCancel(() {
      if (!mounted || run != _run) return;
      _enter.value = 1;
      _settled(run);
    });
  }

  void _finishExit(int run) {
    if (!mounted || run != _run) return;
    setState(() => _replaceOutgoing(null));
  }

  void _settled(int run) {
    if (!mounted || run != _run) return;
    if (_outgoing != null) setState(() => _replaceOutgoing(null));
    _active = SwipeDeckTransition.none;
    widget.onSettled?.call();
  }

  void _replaceOutgoing(ui.Image? image) {
    _outgoing?.dispose();
    _outgoing = image;
  }

  /// A picture of the deck as it was last painted, or null if there is none.
  ui.Image? _capture() {
    final render = _boundary.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary || !render.hasSize) return null;
    try {
      // `debugNeedsPaint` only exists in debug builds; reading it elsewhere
      // throws. A deck that has not painted yet throws below instead.
      var needsPaint = false;
      assert(() {
        needsPaint = render.debugNeedsPaint;
        return true;
      }());
      if (needsPaint) return null;
      final ratio = math.min(MediaQuery.devicePixelRatioOf(context), 2.0);
      return render.toImageSync(pixelRatio: ratio);
    } on Object {
      return null;
    }
  }

  @override
  void dispose() {
    _run++;
    _replaceOutgoing(null);
    _exit.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deck = RepaintBoundary(
      key: _boundary,
      child: KeyedSubtree(
        key: ValueKey<Object>(widget.deckKey),
        child: widget.child,
      ),
    );
    final outgoing = _outgoing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: <Widget>[
            AnimatedBuilder(
              animation: _enter,
              child: deck,
              builder: (context, child) => _incoming(child!, size),
            ),
            if (outgoing != null)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _exit,
                  builder: (context, _) => _leaving(outgoing, size),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _incoming(Widget child, Size size) {
    final t = _enter.value;
    switch (_active) {
      case SwipeDeckTransition.none:
        return child;
      case SwipeDeckTransition.fade:
        return Opacity(opacity: t.clamp(0.0, 1.0), child: child);
      case SwipeDeckTransition.deal:
        // Rises from a little below, a touch smaller, and fades in early.
        final rise = (1 - t) * size.height * 0.16;
        final scale = 0.9 + 0.1 * t;
        return IgnorePointer(
          ignoring: t < 0.85,
          child: Opacity(
            opacity: (t * 2.5).clamp(0.0, 1.0),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.translationValues(0, rise, 0)
                ..multiply(Matrix4.diagonal3Values(scale, scale, 1)),
              child: child,
            ),
          ),
        );
      case SwipeDeckTransition.flip:
        // Mounted but unseen until the old deck is edge-on, so its state is
        // built once.
        if (_outgoing != null) {
          return IgnorePointer(child: Opacity(opacity: 0, child: child));
        }
        final angle = (1 - t) * math.pi / 2;
        return IgnorePointer(
          ignoring: t < 0.85,
          child: Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(angle),
            child: child,
          ),
        );
    }
  }

  Widget _leaving(ui.Image image, Size size) {
    final t = _exit.value;
    final picture = RawImage(
      image: image,
      width: size.width,
      height: size.height,
      fit: BoxFit.fill,
    );
    switch (_active) {
      case SwipeDeckTransition.none:
        return const SizedBox.shrink();
      case SwipeDeckTransition.fade:
        return Opacity(opacity: 1 - t, child: picture);
      case SwipeDeckTransition.deal:
        final eased = Curves.easeInCubic.transform(t);
        final vector = widget.throwDirection.vector;
        final dx = vector.dx * size.width * 1.2 * eased;
        // A thrown card also lifts a little, the way a flick does.
        final dy = (vector.dy * size.height * 1.2 - size.height * 0.06) * eased;
        final turn = (vector.dx == 0 ? 0.06 : vector.dx * 0.22) * eased;
        return Opacity(
          opacity: (1 - Curves.easeIn.transform(t) * 0.9).clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.translationValues(dx, dy, 0)..rotateZ(turn),
            child: picture,
          ),
        );
      case SwipeDeckTransition.flip:
        final angle = -Curves.easeIn.transform(t) * math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform:
              Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
          child: picture,
        );
    }
  }
}
