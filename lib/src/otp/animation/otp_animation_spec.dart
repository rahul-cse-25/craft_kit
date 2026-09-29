import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

@immutable
/// Timing, curves and spring settings for the OTP field animations.
class OtpAnimationSpec {
  /// Creates a spec. Defaults match the built-in look.
  const OtpAnimationSpec({
    this.entranceDuration = const Duration(milliseconds: 820),
    this.entranceStagger = const Duration(milliseconds: 90),
    this.fillDuration = const Duration(milliseconds: 180),
    this.focusDuration = const Duration(milliseconds: 160),
    this.collapseDuration = const Duration(milliseconds: 420),
    this.processingPulseDuration = const Duration(milliseconds: 1200),
    this.resultDuration = const Duration(milliseconds: 680),
    this.restoreDuration = const Duration(milliseconds: 420),
    this.deleteRepeatInitialDelay = const Duration(milliseconds: 260),
    this.deleteRepeatInterval = const Duration(milliseconds: 78),
    this.entranceCurve = Curves.elasticOut,
    this.collapseCurve = Curves.easeInOutCubicEmphasized,
    this.processingCurve = Curves.easeInOutSine,
    this.resultCurve = Curves.easeOutBack,
    this.entranceSpring = const SpringDescription(
      mass: 1.0,
      stiffness: 220.0,
      damping: 18.0,
    ),
  });

  /// Length of the entrance animation of a single box.
  final Duration entranceDuration;

  /// Delay between the entrance start of one box and the next.
  final Duration entranceStagger;

  /// Duration of the fill animation when a digit is entered or removed.
  final Duration fillDuration;

  /// Duration of the focus animation of a box (scale and border).
  final Duration focusDuration;

  /// Duration of the collapse into the processing capsule.
  final Duration collapseDuration;

  /// Duration of one pulse cycle while processing.
  final Duration processingPulseDuration;

  /// Duration of the success or failure result animation.
  final Duration resultDuration;

  /// Duration of restoring the boxes after processing (the reverse of the
  /// collapse).
  final Duration restoreDuration;

  /// How long a delete key must be held before it starts repeating.
  final Duration deleteRepeatInitialDelay;

  /// Interval between repeated deletes while the delete key is held.
  final Duration deleteRepeatInterval;

  /// Curve of the entrance animation.
  final Curve entranceCurve;

  /// Curve of the collapse and restore animation.
  final Curve collapseCurve;

  /// Curve of the processing pulse.
  final Curve processingCurve;

  /// Curve of the result animation.
  final Curve resultCurve;

  /// Spring used by the entrance motion.
  final SpringDescription entranceSpring;

  /// Total entrance time for [length] boxes: [entranceDuration] plus
  /// [entranceStagger] for each box after the first.
  Duration entranceTimelineFor(int length) {
    if (length <= 1) {
      return entranceDuration;
    }

    return entranceDuration + (entranceStagger * (length - 1));
  }

  /// Returns a copy with the given fields replaced.
  OtpAnimationSpec copyWith({
    Duration? entranceDuration,
    Duration? entranceStagger,
    Duration? fillDuration,
    Duration? focusDuration,
    Duration? collapseDuration,
    Duration? processingPulseDuration,
    Duration? resultDuration,
    Duration? restoreDuration,
    Duration? deleteRepeatInitialDelay,
    Duration? deleteRepeatInterval,
    Curve? entranceCurve,
    Curve? collapseCurve,
    Curve? processingCurve,
    Curve? resultCurve,
    SpringDescription? entranceSpring,
  }) {
    return OtpAnimationSpec(
      entranceDuration: entranceDuration ?? this.entranceDuration,
      entranceStagger: entranceStagger ?? this.entranceStagger,
      fillDuration: fillDuration ?? this.fillDuration,
      focusDuration: focusDuration ?? this.focusDuration,
      collapseDuration: collapseDuration ?? this.collapseDuration,
      processingPulseDuration:
          processingPulseDuration ?? this.processingPulseDuration,
      resultDuration: resultDuration ?? this.resultDuration,
      restoreDuration: restoreDuration ?? this.restoreDuration,
      deleteRepeatInitialDelay:
          deleteRepeatInitialDelay ?? this.deleteRepeatInitialDelay,
      deleteRepeatInterval: deleteRepeatInterval ?? this.deleteRepeatInterval,
      entranceCurve: entranceCurve ?? this.entranceCurve,
      collapseCurve: collapseCurve ?? this.collapseCurve,
      processingCurve: processingCurve ?? this.processingCurve,
      resultCurve: resultCurve ?? this.resultCurve,
      entranceSpring: entranceSpring ?? this.entranceSpring,
    );
  }
}
