import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'swipe_direction.dart';
import 'swipe_progress.dart';

/// What dragging a card toward one direction means, for [SwipeIntentOverlay]:
/// the colour, icon and word shown while the card is on its way.
@immutable
class SwipeIntent {
  /// Creates an intent.
  const SwipeIntent({
    required this.direction,
    required this.color,
    required this.icon,
    this.label,
    this.badgeAlignment,
    this.badgeTilt,
  });

  /// The direction that shows this intent.
  final SwipeDirection direction;

  /// The main colour: the wash along the edge, the badge, the label.
  final Color color;

  /// Drawn in the badge.
  final Widget icon;

  /// A word shown under the badge once the drag is far enough to commit.
  final String? label;

  /// Where the badge sits on the card. Defaults to the side away from the
  /// drag (the classic top-left LIKE for a drag to the right), and to the
  /// middle of the far edge when dragging up or down.
  final Alignment? badgeAlignment;

  /// Rotation of the badge in radians. Defaults to a slight lean away from the
  /// drag for horizontal directions and none for vertical ones.
  final double? badgeTilt;
}

/// The overlay drawn over the top card while it is dragged: a soft wash of
/// colour that rises from the edge the card is heading to, and a badge that
/// grows in with the drag and "arms" (swells, rings, shows its word) exactly
/// when releasing would commit.
///
/// Use it as the stack's `overlayBuilder`:
///
/// ```dart
/// overlayBuilder: (context, progress) => SwipeIntentOverlay(
///   progress: progress,
///   borderRadius: BorderRadius.circular(12),
///   intents: [
///     SwipeIntent(direction: SwipeDirection.right, color: green,
///         icon: Icon(Icons.favorite_rounded), label: 'Like'),
///     SwipeIntent(direction: SwipeDirection.left, color: red,
///         icon: Icon(Icons.close_rounded), label: 'Pass'),
///   ],
/// ),
/// ```
///
/// Every direction is drawn from its own progress, so they cross-fade instead
/// of flickering over the diagonal. Nothing here holds state: the picture is a
/// pure function of [progress], so it is exactly right at any moment of a
/// drag, a release or a programmatic swipe, and cheap to redraw.
class SwipeIntentOverlay extends StatelessWidget {
  /// Creates the overlay for the given [intents].
  const SwipeIntentOverlay({
    super.key,
    required this.progress,
    required this.intents,
    this.borderRadius = BorderRadius.zero,
    this.washStrength = 0.6,
    this.badgeSize = 68,
    this.labelStyle,
  }) : assert(washStrength >= 0 && washStrength <= 1),
       assert(badgeSize > 0);

  /// The live drag progress the stack passes to its `overlayBuilder`.
  final SwipeProgress progress;

  /// One entry per direction that should show something.
  final List<SwipeIntent> intents;

  /// Rounds the wash to the card's corners.
  final BorderRadius borderRadius;

  /// How opaque the colour wash gets at the commit threshold (0 to 1).
  final double washStrength;

  /// Diameter of the badge.
  final double badgeSize;

  /// Style of the label. Defaults to a bold, letter-spaced 15 point style in
  /// the intent's colour.
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final layers = <Widget>[];
    for (final intent in intents) {
      final p = progress[intent.direction];
      if (p <= 0) continue;
      layers.add(_IntentLayer(intent: intent, progress: p, overlay: this));
    }
    if (layers.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(fit: StackFit.expand, children: layers),
      ),
    );
  }
}

class _IntentLayer extends StatelessWidget {
  const _IntentLayer({
    required this.intent,
    required this.progress,
    required this.overlay,
  });

  final SwipeIntent intent;
  final double progress;
  final SwipeIntentOverlay overlay;

  static double _smooth(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  @override
  Widget build(BuildContext context) {
    final direction = intent.direction;
    final p = progress.clamp(0.0, 1.0);
    final color = intent.color;

    // The wash grows with the drag and rises from the edge being approached.
    final wash = _smooth(p) * overlay.washStrength;
    final begin = _edge(direction);
    final end = _edge(direction.opposite);

    // The badge appears a little into the drag, then swells to full size.
    final appear = _smooth((p - 0.08) / 0.5);
    // "Armed": releasing now commits. Ramps over the last of the way.
    final armed = _smooth((p - 0.82) / 0.18);
    final scale = (0.55 + 0.45 * appear) * (1 + 0.14 * armed);

    final alignment = intent.badgeAlignment ?? _defaultBadge(direction);
    final tilt = intent.badgeTilt ?? _defaultTilt(direction);
    final size = overlay.badgeSize;
    final label = intent.label;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: <Color>[
                color.withValues(alpha: wash),
                color.withValues(alpha: wash * 0.35),
                color.withValues(alpha: 0),
              ],
              stops: const <double>[0, 0.55, 1],
            ),
          ),
        ),
        Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Opacity(
              opacity: appear,
              child: Transform.rotate(
                angle: tilt * (0.6 + 0.4 * appear),
                child: Transform.scale(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: size,
                        height: size,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color.lerp(color, const Color(0xFFFFFFFF), 0.18)!,
                              Color.lerp(color, const Color(0xFF000000), 0.18)!,
                            ],
                          ),
                          border: Border.all(
                            color: const Color(
                              0xFFFFFFFF,
                            ).withValues(alpha: 0.55 + 0.45 * armed),
                            width: 2 + 2 * armed,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: color.withValues(
                                alpha: 0.35 + 0.35 * armed,
                              ),
                              blurRadius: 14 + 14 * armed,
                              spreadRadius: 2 * armed,
                            ),
                          ],
                        ),
                        child: IconTheme(
                          data: IconThemeData(
                            color: const Color(0xFFFFFFFF),
                            size: size * 0.5,
                          ),
                          child: intent.icon,
                        ),
                      ),
                      if (label != null && armed > 0) ...<Widget>[
                        SizedBox(height: 8 * armed),
                        Opacity(
                          opacity: armed,
                          child: Transform.scale(
                            scale: 0.8 + 0.2 * armed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFFFF),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Text(
                                label.toUpperCase(),
                                style:
                                    overlay.labelStyle ??
                                    TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6,
                                      color: color,
                                      decoration: TextDecoration.none,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Alignment _edge(SwipeDirection d) => switch (d) {
    SwipeDirection.left => Alignment.centerLeft,
    SwipeDirection.right => Alignment.centerRight,
    SwipeDirection.up => Alignment.topCenter,
    SwipeDirection.down => Alignment.bottomCenter,
  };

  static Alignment _defaultBadge(SwipeDirection d) => switch (d) {
    SwipeDirection.right => Alignment.topLeft,
    SwipeDirection.left => Alignment.topRight,
    SwipeDirection.up => Alignment.bottomCenter,
    SwipeDirection.down => Alignment.topCenter,
  };

  static double _defaultTilt(SwipeDirection d) => switch (d) {
    SwipeDirection.right => -math.pi * 0.06,
    SwipeDirection.left => math.pi * 0.06,
    _ => 0,
  };
}
