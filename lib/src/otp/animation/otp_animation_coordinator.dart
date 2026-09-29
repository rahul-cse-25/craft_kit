// ignore_for_file: public_member_api_docs (internal, not exported)

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'otp_animation_spec.dart';

class OtpAnimationCoordinator {
  OtpAnimationCoordinator({
    required TickerProvider vsync,
    required OtpAnimationSpec spec,
    required int length,
  }) : _spec = spec,
       _length = length,
       entranceController = AnimationController(
         vsync: vsync,
         duration: spec.entranceTimelineFor(length),
       ),
       collapseController = AnimationController(
         vsync: vsync,
         duration: spec.collapseDuration,
         reverseDuration: spec.restoreDuration,
       ),
       processingController = AnimationController(
         vsync: vsync,
         duration: spec.processingPulseDuration,
       ),
       resultController = AnimationController(
         vsync: vsync,
         duration: spec.resultDuration,
       );

  OtpAnimationSpec _spec;
  int _length;

  final AnimationController entranceController;
  final AnimationController collapseController;
  final AnimationController processingController;
  final AnimationController resultController;

  Listenable get repaintListenable => Listenable.merge(<Listenable>[
    entranceController,
    collapseController,
    processingController,
    resultController,
  ]);

  void updateSpec({required OtpAnimationSpec spec, required int length}) {
    _spec = spec;
    _length = length;
    entranceController.duration = spec.entranceTimelineFor(length);
    collapseController
      ..duration = spec.collapseDuration
      ..reverseDuration = spec.restoreDuration;
    processingController.duration = spec.processingPulseDuration;
    resultController.duration = spec.resultDuration;
  }

  double entranceProgressFor(int index) {
    final double totalMicros =
        _spec.entranceTimelineFor(_length).inMicroseconds.toDouble();
    final double segmentStart =
        (_spec.entranceStagger * index).inMicroseconds.toDouble();
    final double segmentEnd =
        segmentStart + _spec.entranceDuration.inMicroseconds.toDouble();
    final double currentTime = entranceController.value * totalMicros;
    final double rawProgress = ((currentTime - segmentStart) /
            (segmentEnd - segmentStart))
        .clamp(0.0, 1.0);
    return _spec.entranceCurve.transform(rawProgress);
  }

  Future<void> playEntrance({required bool disableAnimations}) async {
    entranceController.stop();
    if (disableAnimations) {
      entranceController.value = 1;
      return;
    }

    await entranceController.forward(from: 0);
  }

  Future<void> playCollapse({required bool disableAnimations}) async {
    collapseController.stop();
    if (disableAnimations) {
      collapseController.value = 1;
      return;
    }

    await collapseController.forward(from: collapseController.value);
  }

  Future<void> playRestore({required bool disableAnimations}) async {
    stopProcessingLoop();
    resultController.reset();
    if (disableAnimations) {
      collapseController.value = 0;
      return;
    }

    await collapseController.reverse(from: collapseController.value);
  }

  void startProcessingLoop({required bool disableAnimations}) {
    processingController.stop();
    if (disableAnimations) {
      processingController.value = 1;
      return;
    }

    processingController.repeat();
  }

  void stopProcessingLoop({bool reset = true}) {
    processingController.stop();
    if (reset) {
      processingController.value = 0;
    }
  }

  Future<void> playSuccess({required bool disableAnimations}) async {
    resultController.stop();
    if (disableAnimations) {
      resultController.value = 1;
      return;
    }

    await resultController.forward(from: 0);
  }

  Future<void> playFailure({required bool disableAnimations}) async {
    resultController.stop();
    if (disableAnimations) {
      resultController.value = 1;
      return;
    }

    await resultController.forward(from: 0);
  }

  void resetArtifacts() {
    stopProcessingLoop();
    resultController.reset();
    collapseController.value = 0;
  }

  void dispose() {
    entranceController.dispose();
    collapseController.dispose();
    processingController.dispose();
    resultController.dispose();
  }
}
