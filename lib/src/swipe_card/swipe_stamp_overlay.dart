import 'package:flutter/widgets.dart';

import 'swipe_direction.dart';
import 'swipe_progress.dart';

/// One classic stamp for [SwipeStampOverlay]: a word in a coloured frame that
/// fades in as the card is dragged toward [direction].
@immutable
class SwipeStamp {
  /// Creates a stamp.
  const SwipeStamp({
    required this.direction,
    required this.label,
    required this.color,
    this.alignment,
    this.angle,
  });

  /// The direction that shows this stamp.
  final SwipeDirection direction;

  /// The word, for example `LIKE`.
  final String label;

  /// The colour of the frame and the word.
  final Color color;

  /// Where the word sits on the card. Defaults to the corner away from the
  /// drag (top left for a drag to the right, top right for the left), the
  /// bottom centre for up and the top centre for down.
  final Alignment? alignment;

  /// Rotation of the word in radians. Defaults to a lean of about 14 degrees
  /// away from the drag for horizontal directions, and none otherwise.
  final double? angle;
}

/// The classic drag overlay: a coloured frame around the card and a rotated
/// word in the corner (LIKE, NOPE...), both fading in with the drag.
///
/// ```dart
/// overlayBuilder: (context, progress) => SwipeStampOverlay(
///   progress: progress,
///   borderRadius: BorderRadius.circular(28),
///   stamps: const [
///     SwipeStamp(direction: SwipeDirection.right, label: 'LIKE',
///         color: Colors.green),
///     SwipeStamp(direction: SwipeDirection.left, label: 'NOPE',
///         color: Colors.red),
///   ],
/// ),
/// ```
///
/// Every direction is drawn from its own progress, so they fade in and out
/// independently and never flicker across the diagonal.
class SwipeStampOverlay extends StatelessWidget {
  /// Creates the overlay for the given [stamps].
  const SwipeStampOverlay({
    super.key,
    required this.progress,
    required this.stamps,
    this.borderRadius = BorderRadius.zero,
    this.borderWidth = 4,
    this.fontSize = 38,
    this.padding = 28,
  });

  /// The live drag progress the stack passes to its `overlayBuilder`.
  final SwipeProgress progress;

  /// One entry per direction that should show a stamp.
  final List<SwipeStamp> stamps;

  /// Rounds the frame; use the card's radius.
  final BorderRadius borderRadius;

  /// Thickness of the frame.
  final double borderWidth;

  /// Size of the word.
  final double fontSize;

  /// Space between the word and the card's edge.
  final double padding;

  @override
  Widget build(BuildContext context) {
    final layers = <Widget>[
      for (final stamp in stamps)
        if (progress[stamp.direction] > 0) _layer(stamp),
    ];
    if (layers.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(child: Stack(fit: StackFit.expand, children: layers));
  }

  Widget _layer(SwipeStamp stamp) {
    final value = progress[stamp.direction].clamp(0.0, 1.0);
    return Opacity(
      opacity: value,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: stamp.color, width: borderWidth),
        ),
        child: Align(
          alignment: stamp.alignment ?? _alignment(stamp.direction),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Transform.rotate(
              angle: stamp.angle ?? _angle(stamp.direction),
              child: Text(
                stamp.label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: stamp.color,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Alignment _alignment(SwipeDirection d) => switch (d) {
    SwipeDirection.right => Alignment.topLeft,
    SwipeDirection.left => Alignment.topRight,
    SwipeDirection.up => Alignment.bottomCenter,
    SwipeDirection.down => Alignment.topCenter,
  };

  static double _angle(SwipeDirection d) => switch (d) {
    SwipeDirection.right => -0.25,
    SwipeDirection.left => 0.25,
    _ => 0,
  };
}
