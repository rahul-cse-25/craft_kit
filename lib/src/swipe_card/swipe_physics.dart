import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

/// A spring described by how stiff and how damped it is.
@immutable
class SwipeSpring {
  /// Creates a spring.
  ///
  /// [dampingRatio] 1 is critically damped (no overshoot); below 1 overshoots
  /// and oscillates; above 1 is sluggish.
  const SwipeSpring({
    required this.stiffness,
    this.dampingRatio = 1,
    this.mass = 1,
  });

  /// Stiffness in N/m. Higher is faster.
  final double stiffness;

  /// Damping ratio. 1 is critical damping.
  final double dampingRatio;

  /// Mass of the card.
  final double mass;

  /// The spring for `flutter/physics`.
  SpringDescription get description => SpringDescription.withDampingRatio(
    mass: mass,
    stiffness: stiffness,
    ratio: dampingRatio,
  );

  @override
  bool operator ==(Object other) =>
      other is SwipeSpring &&
      other.stiffness == stiffness &&
      other.dampingRatio == dampingRatio &&
      other.mass == mass;

  @override
  int get hashCode => Object.hash(stiffness, dampingRatio, mass);
}

/// Every number that shapes how the cards feel: when a release commits, how
/// the cards move, and how they resist.
///
/// All movement is spring based. A release starts its spring with the card's
/// current position and velocity, so there is no jump between the finger and
/// the animation, and a card can be caught at any moment.
@immutable
class SwipePhysics {
  /// Creates a physics description. The defaults are the "smooth" preset.
  const SwipePhysics({
    this.commitThreshold = 0.3,
    this.projectionTime = 0.18,
    this.minCommitDistance = 8,
    this.maxAngle = 0.25,
    this.grabTilt = true,
    this.rubberBandLimit = 36,
    this.programmaticSpeed = 1400,
    this.triggerKick = 900,
    this.settle = const SwipeSpring(stiffness: 320, dampingRatio: 0.72),
    this.fling = const SwipeSpring(stiffness: 140, dampingRatio: 0.9),
    this.consume = const SwipeSpring(stiffness: 210),
    this.undo = const SwipeSpring(stiffness: 240, dampingRatio: 0.8),
    this.promote = const SwipeSpring(stiffness: 260),
  }) : assert(commitThreshold > 0 && commitThreshold <= 1),
       assert(projectionTime >= 0),
       assert(rubberBandLimit > 0);

  /// Smooth and natural. The default.
  static const SwipePhysics smooth = SwipePhysics();

  /// Stiffer and quicker, with little overshoot.
  static const SwipePhysics snappy = SwipePhysics(
    settle: SwipeSpring(stiffness: 520, dampingRatio: 0.85),
    fling: SwipeSpring(stiffness: 220, dampingRatio: 0.95),
    consume: SwipeSpring(stiffness: 320),
    undo: SwipeSpring(stiffness: 380, dampingRatio: 0.9),
    promote: SwipeSpring(stiffness: 420),
  );

  /// Loose and playful, with visible overshoot when cards spring back.
  static const SwipePhysics bouncy = SwipePhysics(
    settle: SwipeSpring(stiffness: 240, dampingRatio: 0.5),
    fling: SwipeSpring(stiffness: 110, dampingRatio: 0.85),
    consume: SwipeSpring(stiffness: 170, dampingRatio: 0.9),
    undo: SwipeSpring(stiffness: 200, dampingRatio: 0.55),
    promote: SwipeSpring(stiffness: 210, dampingRatio: 0.9),
  );

  /// How far a card must travel to commit, as a fraction of its width (for
  /// left and right) or height (for up and down).
  ///
  /// It is compared against the *projected* end position, so a quick flick
  /// commits after a short distance and a slow drag needs to go further.
  final double commitThreshold;

  /// Seconds of the release velocity that are added to the position to
  /// project where the card is heading. Larger makes flicks more effective.
  final double projectionTime;

  /// The card must have moved at least this many pixels toward a direction
  /// for a release to commit, so a tap or a tiny nudge never does.
  final double minCommitDistance;

  /// Tilt, in radians, at the edge of the card's width.
  final double maxAngle;

  /// Whether the tilt follows where the card was grabbed (grab the top and it
  /// swings one way, grab the bottom and it swings the other).
  final bool grabTilt;

  /// The most, in pixels, a card can be pulled toward a direction that has no
  /// behavior. It stretches with growing resistance and springs back.
  final double rubberBandLimit;

  /// Launch speed, in pixels per second, of a programmatic swipe.
  final double programmaticSpeed;

  /// Launch speed of the kick a programmatic swipe gives a spring-back card.
  final double triggerKick;

  /// Spring for a card returning to the stack.
  final SwipeSpring settle;

  /// Spring for a card leaving the screen.
  final SwipeSpring fling;

  /// Spring for a card travelling into a target.
  final SwipeSpring consume;

  /// Spring for an undone card coming back.
  final SwipeSpring undo;

  /// Spring for the cards behind moving up a place.
  final SwipeSpring promote;

  /// A copy with some values replaced.
  SwipePhysics copyWith({
    double? commitThreshold,
    double? projectionTime,
    double? minCommitDistance,
    double? maxAngle,
    bool? grabTilt,
    double? rubberBandLimit,
    double? programmaticSpeed,
    double? triggerKick,
    SwipeSpring? settle,
    SwipeSpring? fling,
    SwipeSpring? consume,
    SwipeSpring? undo,
    SwipeSpring? promote,
  }) {
    return SwipePhysics(
      commitThreshold: commitThreshold ?? this.commitThreshold,
      projectionTime: projectionTime ?? this.projectionTime,
      minCommitDistance: minCommitDistance ?? this.minCommitDistance,
      maxAngle: maxAngle ?? this.maxAngle,
      grabTilt: grabTilt ?? this.grabTilt,
      rubberBandLimit: rubberBandLimit ?? this.rubberBandLimit,
      programmaticSpeed: programmaticSpeed ?? this.programmaticSpeed,
      triggerKick: triggerKick ?? this.triggerKick,
      settle: settle ?? this.settle,
      fling: fling ?? this.fling,
      consume: consume ?? this.consume,
      undo: undo ?? this.undo,
      promote: promote ?? this.promote,
    );
  }
}
