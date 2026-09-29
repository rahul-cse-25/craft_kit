import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Kinds of haptic feedback the OTP field can trigger.
enum OtpHapticType {
  /// A light impact.
  lightImpact,

  /// A medium impact.
  mediumImpact,

  /// A heavy impact.
  heavyImpact,

  /// A selection tick.
  selectionClick,

  /// A generic vibration.
  vibrate,
}

/// Helpers for [OtpHapticType].
extension OtpHapticTypeX on OtpHapticType {
  /// Plays the matching [HapticFeedback] effect.
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
/// Haptic feedback used by the OTP field for its results.
class OtpHaptics {
  /// Creates a haptics setting. Defaults: light impact on success, heavy
  /// impact on failure.
  const OtpHaptics({
    this.success = OtpHapticType.lightImpact,
    this.failure = OtpHapticType.heavyImpact,
  });

  /// Feedback played on success, or null for none.
  final OtpHapticType? success;

  /// Feedback played on failure, or null for none.
  final OtpHapticType? failure;
}
