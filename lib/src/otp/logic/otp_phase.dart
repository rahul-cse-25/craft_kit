enum OtpPhase {
  idle,
  entering,
  editing,
  complete,
  collapsing,
  processing,
  success,
  failure,
  restoring,
}

extension OtpPhaseX on OtpPhase {
  bool get isBusy => switch (this) {
    OtpPhase.collapsing ||
    OtpPhase.processing ||
    OtpPhase.success ||
    OtpPhase.failure ||
    OtpPhase.restoring => true,
    _ => false,
  };

  bool get isResult => switch (this) {
    OtpPhase.success || OtpPhase.failure => true,
    _ => false,
  };
}
