/// Stage of the OTP field lifecycle.
enum OtpPhase {
  /// Nothing entered and no entrance animation running.
  idle,

  /// The boxes are animating in.
  entering,

  /// The user is typing and the code is not yet full.
  editing,

  /// All digits are entered.
  complete,

  /// The boxes are collapsing into the processing capsule.
  collapsing,

  /// The code is being verified.
  processing,

  /// Verification succeeded.
  success,

  /// Verification failed.
  failure,

  /// The boxes are expanding back after processing.
  restoring,
}

/// Helpers for [OtpPhase].
extension OtpPhaseX on OtpPhase {
  /// Whether the field is collapsing, processing, showing a result or
  /// restoring, so input is not expected.
  bool get isBusy => switch (this) {
    OtpPhase.collapsing ||
    OtpPhase.processing ||
    OtpPhase.success ||
    OtpPhase.failure ||
    OtpPhase.restoring => true,
    _ => false,
  };

  /// Whether this phase shows a result, that is success or failure.
  bool get isResult => switch (this) {
    OtpPhase.success || OtpPhase.failure => true,
    _ => false,
  };
}
