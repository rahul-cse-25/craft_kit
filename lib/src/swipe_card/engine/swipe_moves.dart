import 'dart:ui' show Offset, lerpDouble;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

import 'swipe_math.dart' show SwipePath;

/// Where a card is and how it looks.
@immutable
class SwipePose {
  /// Creates a pose.
  const SwipePose({
    this.offset = Offset.zero,
    this.rotation = 0,
    this.scale = 1,
    this.opacity = 1,
  });

  /// Resting pose.
  static const SwipePose identity = SwipePose();

  /// Displacement from the card's resting place.
  final Offset offset;

  /// Rotation in radians.
  final double rotation;

  /// Scale.
  final double scale;

  /// Opacity, 0 to 1.
  final double opacity;

  @override
  bool operator ==(Object other) =>
      other is SwipePose &&
      other.offset == offset &&
      other.rotation == rotation &&
      other.scale == scale &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(offset, rotation, scale, opacity);
}

/// The tolerance at which a move counts as finished: a twentieth of a pixel
/// and a couple of pixels per second, far below anything visible.
const Tolerance swipeTolerance = Tolerance(distance: 0.05, velocity: 2);

/// A card animation. Time is in seconds since the move started.
///
/// Moves are analytic (springs are solved in closed form), so the pose at any
/// moment is exact no matter how late a frame arrives.
abstract class SwipeMove {
  /// The pose at [t].
  SwipePose at(double t);

  /// The velocity of the card, in pixels per second, at [t].
  Offset velocityAt(double t);

  /// Whether the move has finished at [t].
  bool isDone(double t);

  /// The exact pose the move ends in.
  SwipePose get finalPose;
}

/// The card follows a spring toward [to], starting with the given velocity.
///
/// Scale and opacity can change too (used when an undone card comes back from
/// the shrunk state of a consumed card).
class SpringMove extends SwipeMove {
  /// Creates the move.
  SpringMove({
    required Offset from,
    required Offset velocity,
    required this.to,
    required SpringDescription spring,
    required this.rotationFor,
    this.fromScale = 1,
    this.toScale = 1,
    this.fromOpacity = 1,
    this.toOpacity = 1,
    this.isOut,
  }) : _x = SpringSimulation(
         spring,
         from.dx,
         to.dx,
         velocity.dx,
         tolerance: swipeTolerance,
       ),
       _y = SpringSimulation(
         spring,
         from.dy,
         to.dy,
         velocity.dy,
         tolerance: swipeTolerance,
       ),
       _blend = SpringSimulation(
         spring,
         0,
         1,
         0,
         tolerance: const Tolerance(distance: 0.002, velocity: 0.05),
       );

  /// Where the card ends up.
  final Offset to;

  /// Tilt for a given displacement.
  final double Function(Offset offset) rotationFor;

  /// Scale at the start and the end.
  final double fromScale, toScale;

  /// Opacity at the start and the end.
  final double fromOpacity, toOpacity;

  /// When set, the move also ends as soon as this returns true (used so a card
  /// leaving the screen finishes when it is off it, instead of creeping toward
  /// a far-away target).
  final bool Function(Offset offset)? isOut;

  final SpringSimulation _x;
  final SpringSimulation _y;
  final SpringSimulation _blend;

  @override
  SwipePose at(double t) {
    final o = Offset(_x.x(t), _y.x(t));
    final b = _blend.x(t).clamp(0.0, 1.0);
    return SwipePose(
      offset: o,
      rotation: rotationFor(o),
      scale: lerpDouble(fromScale, toScale, b)!,
      opacity: lerpDouble(fromOpacity, toOpacity, b)!.clamp(0.0, 1.0),
    );
  }

  @override
  Offset velocityAt(double t) => Offset(_x.dx(t), _y.dx(t));

  @override
  bool isDone(double t) {
    final out = isOut;
    if (out != null && out(Offset(_x.x(t), _y.x(t)))) return true;
    return _x.isDone(t) && _y.isDone(t) && _blend.isDone(t);
  }

  @override
  SwipePose get finalPose => SwipePose(
    offset: to,
    rotation: rotationFor(to),
    scale: toScale,
    opacity: toOpacity,
  );
}

/// The card travels along a [SwipePath], shrinking (and fading) on the way.
///
/// One spring drives the progress along the path, so the position, scale and
/// fade always stay in step.
class PathMove extends SwipeMove {
  /// Creates the move.
  PathMove({
    required this.path,
    required double progressVelocity,
    required SpringDescription spring,
    required this.fromRotation,
    this.fromScale = 1,
    required this.endScale,
    required this.fade,
  }) : _p = SpringSimulation(
         spring,
         0,
         1,
         progressVelocity,
         tolerance: const Tolerance(distance: 0.002, velocity: 0.02),
       );

  /// The route.
  final SwipePath path;

  /// Tilt when the move starts; it eases to 0 on the way.
  final double fromRotation;

  /// Scale when the move starts.
  final double fromScale;

  /// Scale on arrival.
  final double endScale;

  /// Whether the card fades out over the last part.
  final bool fade;

  final SpringSimulation _p;

  /// Progress along the path at [t], 0 to 1.
  double progressAt(double t) => _p.x(t).clamp(0.0, 1.0);

  @override
  SwipePose at(double t) {
    final p = progressAt(t);
    final shrink = Curves.easeInQuad.transform(p);
    var opacity = 1.0;
    if (fade) {
      final f = ((p - 0.7) / 0.3).clamp(0.0, 1.0);
      opacity = 1 - f * f * (3 - 2 * f); // smoothstep
    }
    return SwipePose(
      offset: path.at(p),
      rotation: fromRotation * (1 - p),
      scale: lerpDouble(fromScale, endScale, shrink)!,
      opacity: opacity,
    );
  }

  @override
  Offset velocityAt(double t) {
    const h = 0.001;
    return (at(t + h).offset - at(t).offset) / h;
  }

  @override
  bool isDone(double t) => _p.isDone(t);

  @override
  SwipePose get finalPose =>
      SwipePose(offset: path.to, scale: endScale, opacity: fade ? 0 : 1);
}

/// A single value springing toward zero. Used for the "remaining promotion" of
/// the cards behind the top one.
class ScalarSpring {
  /// Starts at [from] with [velocity] and springs toward 0.
  ScalarSpring({
    required this.from,
    required double velocity,
    required SpringDescription spring,
  }) : _sim = SpringSimulation(
         spring,
         from,
         0,
         velocity,
         tolerance: const Tolerance(distance: 0.0005, velocity: 0.01),
       );

  /// The starting value.
  final double from;

  final SpringSimulation _sim;

  /// The value at [t].
  double value(double t) => _sim.x(t);

  /// The rate of change at [t].
  double velocity(double t) => _sim.dx(t);

  /// Whether it has settled.
  bool isDone(double t) => _sim.isDone(t);
}
