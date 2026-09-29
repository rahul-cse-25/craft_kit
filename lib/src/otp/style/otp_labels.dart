import 'package:flutter/foundation.dart';

String _defaultValue(int filled, int total) =>
    '$filled of $total digits entered';

/// User-facing strings of the OTP field (accessibility only). Override them to
/// localize the field.
@immutable
class OtpLabels {
  /// Creates a set of labels. Defaults are English.
  const OtpLabels({
    this.inputLabel = 'One-time password input',
    this.valueBuilder = _defaultValue,
    this.emptyHint = 'Tap to enter the verification code.',
    this.filledHint = 'Tap to focus. Long press to delete continuously.',
  });

  /// Semantics label of the whole field.
  final String inputLabel;

  /// Builds the semantics value from (filled digits, total digits).
  final String Function(int filled, int total) valueBuilder;

  /// Semantics hint while no digit is entered.
  final String emptyHint;

  /// Semantics hint once at least one digit is entered.
  final String filledHint;
}
