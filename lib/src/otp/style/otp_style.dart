import 'package:flutter/material.dart';

/// How the glow and icon shadow of the success and failure result look.
enum OtpResultGlow {
  /// The glow uses [OtpStyle.glowColor] and the icon shadow is white. This is
  /// the look of `const OtpStyle()`.
  classic,

  /// The glow takes the middle color of the result gradient, is a little
  /// stronger, and the icon shadow uses the icon color. This is the look of
  /// [OtpStyle.fromTheme].
  followGradient,
}

/// Visual configuration of an OTP field.
///
/// `const OtpStyle()` is a dark-surface look (white text, white outlines,
/// violet focus). Use [OtpStyle.fromTheme] to derive colors from a
/// [ThemeData], which is what `OtpCodeField` does when no style is given.
@immutable
class OtpStyle {
  /// Creates a style. Defaults describe the dark-surface look.
  const OtpStyle({
    this.boxWidth = 48,
    this.boxHeight = 48,
    this.gap = 12,
    this.idleRadius = 8,
    this.filledRadius = 12,
    this.borderWidth = 1.4,
    this.focusedBorderWidth = 1.8,
    this.focusScale = 1.03,
    this.processingWidthFactor = 1.48,
    this.canvasVerticalPadding = 44,
    this.resultGlow = OtpResultGlow.classic,
    this.backgroundColor = Colors.transparent,
    this.filledBackgroundColor = Colors.transparent,
    this.borderColor = Colors.white12,
    this.focusedBorderColor = const Color(0xFF6C4DFF),
    this.filledBorderColor = const Color(0xFF32D583),
    this.successBorderColor = const Color(0xFF32D583),
    this.errorBorderColor = const Color(0xFFFF6B7A),
    this.textColor = Colors.white,
    this.processingDotColor = Colors.white,
    this.processingTrackColor = const Color(0x40FFFFFF),
    this.processingHighlightColor = const Color(0x80FFFFFF),
    this.processingOutlineColor = const Color(0x3DFFFFFF),
    this.processingGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF7C4DFF), Color(0xFF4E8DFF), Color(0xFF28D7B5)],
    ),
    this.successGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF1CB57B), Color(0xFF48E1A6)],
    ),
    this.failureGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFFF5B7F), Color(0xFFFF7A59)],
    ),
    this.glowColor = const Color(0x805C6BFF),
    this.resultIconColor = Colors.white,
    this.textStyle = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1,
      color: Colors.white,
    ),
  });

  /// Derives colors from [theme], so the field looks right on light and dark
  /// surfaces.
  ///
  /// Surfaces, borders and text follow the [ColorScheme]; the success and
  /// failure gradients are tuned separately for light and dark. It also
  /// selects the tighter field height ([canvasVerticalPadding] 24) and
  /// [OtpResultGlow.followGradient]; override either afterwards with
  /// [copyWith]. Pass [base] to keep custom geometry (box size, gap, radii).
  factory OtpStyle.fromTheme(
    ThemeData theme, {
    OtpStyle base = const OtpStyle(),
  }) {
    final ColorScheme colors = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    const Color success = Color(0xFF2E7D5A);

    return base.copyWith(
      canvasVerticalPadding: 24,
      resultGlow: OtpResultGlow.followGradient,
      backgroundColor: colors.surface,
      filledBackgroundColor: colors.primaryContainer.withValues(alpha: 0.34),
      borderColor: colors.outlineVariant,
      focusedBorderColor: colors.primary,
      filledBorderColor: success,
      successBorderColor: success,
      errorBorderColor: colors.error,
      textColor: colors.onSurface,
      processingDotColor: colors.onSurface,
      processingTrackColor: colors.onSurface.withValues(alpha: 0.20),
      processingHighlightColor: colors.onSurface.withValues(alpha: 0.56),
      processingOutlineColor: colors.onSurface.withValues(alpha: 0.20),
      processingGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[colors.primary, colors.secondary, colors.tertiary],
      ),
      successGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors:
            isDark
                ? const <Color>[
                  Color(0xFF6EE7B7),
                  Color(0xFF10B981),
                  Color(0xFF2DD4BF),
                ]
                : const <Color>[
                  Color(0xFF047857),
                  Color(0xFF10B981),
                  Color(0xFF2DD4BF),
                ],
        stops: const <double>[0, 0.52, 1],
      ),
      failureGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors:
            isDark
                ? const <Color>[
                  Color(0xFFFF8AA0),
                  Color(0xFFF43F5E),
                  Color(0xFFFFA45B),
                ]
                : const <Color>[
                  Color(0xFFBE123C),
                  Color(0xFFF43F5E),
                  Color(0xFFF97316),
                ],
        stops: const <double>[0, 0.52, 1],
      ),
      glowColor: colors.primary.withValues(alpha: 0.35),
      resultIconColor: colors.onSurface,
      textStyle:
          theme.textTheme.titleMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
            height: 1,
          ) ??
          TextStyle(
            color: colors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
    );
  }

  /// Width of each digit box, in logical pixels.
  final double boxWidth;

  /// Height of each digit box, in logical pixels.
  final double boxHeight;

  /// Space between neighboring boxes, in logical pixels.
  final double gap;

  /// Corner radius of an empty box.
  final double idleRadius;

  /// Corner radius of a box holding a digit.
  final double filledRadius;

  /// Border width of an unfocused box.
  final double borderWidth;

  /// Border width of the focused box.
  final double focusedBorderWidth;

  /// Scale applied to the focused box (1 means no scaling).
  final double focusScale;

  /// Width multiplier for the processing capsule relative to a box. Not
  /// currently read by the widgets.
  final double processingWidthFactor;

  /// Extra height added around the boxes for the entrance motion and the
  /// glow. The field is `boxHeight + canvasVerticalPadding` tall.
  final double canvasVerticalPadding;

  /// Look of the success and failure glow. See [OtpResultGlow].
  final OtpResultGlow resultGlow;

  /// Fill color of an empty box.
  final Color backgroundColor;

  /// Fill color of a box holding a digit.
  final Color filledBackgroundColor;

  /// Border color of an empty, unfocused box.
  final Color borderColor;

  /// Border color of the focused box.
  final Color focusedBorderColor;

  /// Border color of a box holding a digit.
  final Color filledBorderColor;

  /// Border color when the result is success.
  final Color successBorderColor;

  /// Border color when the result is failure.
  final Color errorBorderColor;

  /// Color of the digits.
  final Color textColor;

  /// Color of the dots shown while processing.
  final Color processingDotColor;

  /// Color of the track behind the processing dots.
  final Color processingTrackColor;

  /// Color of the highlight flash while processing.
  final Color processingHighlightColor;

  /// Color of the capsule outline while processing.
  final Color processingOutlineColor;

  /// Gradient of the processing capsule.
  final LinearGradient processingGradient;

  /// Gradient of the success result.
  final LinearGradient successGradient;

  /// Gradient of the failure result.
  final LinearGradient failureGradient;

  /// Glow color of the result under [OtpResultGlow.classic].
  final Color glowColor;

  /// Color of the success and failure icon.
  final Color resultIconColor;

  /// Text style of the digits.
  final TextStyle textStyle;

  /// Returns a copy with the given fields replaced.
  OtpStyle copyWith({
    double? boxWidth,
    double? boxHeight,
    double? gap,
    double? idleRadius,
    double? filledRadius,
    double? borderWidth,
    double? focusedBorderWidth,
    double? focusScale,
    double? processingWidthFactor,
    double? canvasVerticalPadding,
    OtpResultGlow? resultGlow,
    Color? backgroundColor,
    Color? filledBackgroundColor,
    Color? borderColor,
    Color? focusedBorderColor,
    Color? filledBorderColor,
    Color? successBorderColor,
    Color? errorBorderColor,
    Color? textColor,
    Color? processingDotColor,
    Color? processingTrackColor,
    Color? processingHighlightColor,
    Color? processingOutlineColor,
    LinearGradient? processingGradient,
    LinearGradient? successGradient,
    LinearGradient? failureGradient,
    Color? glowColor,
    Color? resultIconColor,
    TextStyle? textStyle,
  }) {
    return OtpStyle(
      boxWidth: boxWidth ?? this.boxWidth,
      boxHeight: boxHeight ?? this.boxHeight,
      gap: gap ?? this.gap,
      idleRadius: idleRadius ?? this.idleRadius,
      filledRadius: filledRadius ?? this.filledRadius,
      borderWidth: borderWidth ?? this.borderWidth,
      focusedBorderWidth: focusedBorderWidth ?? this.focusedBorderWidth,
      focusScale: focusScale ?? this.focusScale,
      processingWidthFactor:
          processingWidthFactor ?? this.processingWidthFactor,
      canvasVerticalPadding:
          canvasVerticalPadding ?? this.canvasVerticalPadding,
      resultGlow: resultGlow ?? this.resultGlow,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      filledBackgroundColor:
          filledBackgroundColor ?? this.filledBackgroundColor,
      borderColor: borderColor ?? this.borderColor,
      focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
      filledBorderColor: filledBorderColor ?? this.filledBorderColor,
      successBorderColor: successBorderColor ?? this.successBorderColor,
      errorBorderColor: errorBorderColor ?? this.errorBorderColor,
      textColor: textColor ?? this.textColor,
      processingDotColor: processingDotColor ?? this.processingDotColor,
      processingTrackColor: processingTrackColor ?? this.processingTrackColor,
      processingHighlightColor:
          processingHighlightColor ?? this.processingHighlightColor,
      processingOutlineColor:
          processingOutlineColor ?? this.processingOutlineColor,
      processingGradient: processingGradient ?? this.processingGradient,
      successGradient: successGradient ?? this.successGradient,
      failureGradient: failureGradient ?? this.failureGradient,
      glowColor: glowColor ?? this.glowColor,
      resultIconColor: resultIconColor ?? this.resultIconColor,
      textStyle: textStyle ?? this.textStyle,
    );
  }
}
