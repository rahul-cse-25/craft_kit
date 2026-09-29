import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Where and how a card sits at a given depth in the stack.
@immutable
class SwipeSlot {
  /// Creates a slot.
  const SwipeSlot({
    this.offset = Offset.zero,
    this.scale = 1,
    this.rotation = 0,
    this.opacity = 1,
    this.alignment = Alignment.center,
  });

  /// Shift from the top card's position.
  final Offset offset;

  /// Scale, around [alignment].
  final double scale;

  /// Rotation in radians, around [alignment].
  final double rotation;

  /// Opacity, 0 to 1.
  final double opacity;

  /// The point of the card that [scale] and [rotation] pivot around.
  final Alignment alignment;
}

/// How the cards behind the top one are laid out.
///
/// Implement it to change the look: a fan, a carousel, a deck with a fade. A
/// layout is only a function from depth to a [SwipeSlot]. `depth` is
/// fractional while cards move up a place, so the layout stays smooth as long
/// as [slotAt] is continuous.
abstract class SwipeStackLayout {
  /// Creates a layout.
  const SwipeStackLayout();

  /// How many cards are fully visible, top card included. One more is built
  /// but stays invisible until it moves up.
  int get visibleCards;

  /// Room the stack keeps free around the top card for the cards peeking out
  /// behind it. The top card is that much smaller than the space given to the
  /// stack.
  EdgeInsets get reserve;

  /// The slot at [depth]. 0 is the top card; 1 the card right behind it.
  SwipeSlot slotAt(double depth);
}

/// Cards behind the top one peek out below it, each a bit narrower.
class CascadeLayout extends SwipeStackLayout {
  /// Creates the layout.
  const CascadeLayout({
    this.visibleCards = 3,
    this.offset = 14,
    this.scaleStep = 0.06,
    this.tilt = 0,
  }) : assert(visibleCards > 0),
       assert(offset >= 0),
       assert(scaleStep >= 0 && scaleStep < 1);

  @override
  final int visibleCards;

  /// Pixels each card behind peeks out below the one in front.
  final double offset;

  /// How much narrower each card behind is, per level.
  final double scaleStep;

  /// Radians of rotation added per level, for a fanned look.
  final double tilt;

  @override
  EdgeInsets get reserve =>
      EdgeInsets.only(bottom: offset * (visibleCards - 1));

  @override
  SwipeSlot slotAt(double depth) {
    final d = math.max(0.0, depth);
    return SwipeSlot(
      offset: Offset(0, offset * d),
      scale: math.max(0.0, 1 - scaleStep * d),
      rotation: tilt * d,
      opacity: (visibleCards - d).clamp(0.0, 1.0),
      alignment: Alignment.bottomCenter,
    );
  }
}
