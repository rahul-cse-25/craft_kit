import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

@immutable
class OtpAnimationSpec {
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

  final Duration entranceDuration;
  final Duration entranceStagger;
  final Duration fillDuration;
  final Duration focusDuration;
  final Duration collapseDuration;
  final Duration processingPulseDuration;
  final Duration resultDuration;
  final Duration restoreDuration;
  final Duration deleteRepeatInitialDelay;
  final Duration deleteRepeatInterval;
  final Curve entranceCurve;
  final Curve collapseCurve;
  final Curve processingCurve;
  final Curve resultCurve;
  final SpringDescription entranceSpring;

  Duration entranceTimelineFor(int length) {
    if (length <= 1) {
      return entranceDuration;
    }

    return entranceDuration + (entranceStagger * (length - 1));
  }

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
