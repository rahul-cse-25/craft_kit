// ignore_for_file: public_member_api_docs (internal, not exported)

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'otp_phase.dart';

@immutable
class OtpRenderModel {
  const OtpRenderModel({
    required this.code,
    required this.length,
    required this.phase,
    required this.hasFocus,
    required this.enabled,
  });

  final String code;
  final int length;
  final OtpPhase phase;
  final bool hasFocus;
  final bool enabled;

  int get filledCount => math.min(code.length, length);

  bool get isComplete => filledCount == length;

  int? get focusedIndex {
    if (!hasFocus || length == 0) {
      return null;
    }

    if (isComplete) {
      return length - 1;
    }

    return math.min(filledCount, length - 1);
  }

  OtpRenderModel copyWith({
    String? code,
    int? length,
    OtpPhase? phase,
    bool? hasFocus,
    bool? enabled,
  }) {
    return OtpRenderModel(
      code: code ?? this.code,
      length: length ?? this.length,
      phase: phase ?? this.phase,
      hasFocus: hasFocus ?? this.hasFocus,
      enabled: enabled ?? this.enabled,
    );
  }
}
