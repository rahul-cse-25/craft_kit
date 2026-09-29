import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A kind of haptic feedback.
enum SwipeHapticType {
  /// A very light tick.
  selectionClick,

  /// A light tap.
  lightImpact,

  /// A medium tap.
  mediumImpact,

  /// A heavy tap.
  heavyImpact,
}

/// Performs a [SwipeHapticType].
extension SwipeHapticTypeX on SwipeHapticType {
  /// Fires the feedback.
  Future<void> perform() => switch (this) {
    SwipeHapticType.selectionClick => HapticFeedback.selectionClick(),
    SwipeHapticType.lightImpact => HapticFeedback.lightImpact(),
    SwipeHapticType.mediumImpact => HapticFeedback.mediumImpact(),
    SwipeHapticType.heavyImpact => HapticFeedback.heavyImpact(),
  };
}

/// Which haptic feedback a card stack gives. Use null to turn one off.
@immutable
class SwipeHaptics {
  /// Creates a haptics description.
  const SwipeHaptics({
    this.thresholdCrossed = SwipeHapticType.selectionClick,
    this.commit = SwipeHapticType.lightImpact,
  });

  /// No haptics at all.
  static const SwipeHaptics none = SwipeHaptics(
    thresholdCrossed: null,
    commit: null,
  );

  /// When a drag crosses the commit threshold, so the user can feel that
  /// letting go now will commit (and that pulling back will cancel).
  final SwipeHapticType? thresholdCrossed;

  /// When a swipe commits.
  final SwipeHapticType? commit;
}
