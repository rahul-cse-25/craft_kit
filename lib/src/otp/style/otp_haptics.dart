import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum OtpHapticType {
  lightImpact,
  mediumImpact,
  heavyImpact,
  selectionClick,
  vibrate,
}

extension OtpHapticTypeX on OtpHapticType {
  Future<void> perform() {
    return switch (this) {
      OtpHapticType.lightImpact => HapticFeedback.lightImpact(),
      OtpHapticType.mediumImpact => HapticFeedback.mediumImpact(),
      OtpHapticType.heavyImpact => HapticFeedback.heavyImpact(),
      OtpHapticType.selectionClick => HapticFeedback.selectionClick(),
      OtpHapticType.vibrate => HapticFeedback.vibrate(),
    };
  }
}

@immutable
class OtpHaptics {
  const OtpHaptics({
    this.success = OtpHapticType.lightImpact,
    this.failure = OtpHapticType.heavyImpact,
  });

  final OtpHapticType? success;
  final OtpHapticType? failure;
}
