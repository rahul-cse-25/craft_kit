import 'package:flutter/material.dart';

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
  /// surfaces. Pass [base] to keep custom geometry and only re-color.
  factory OtpStyle.fromTheme(
    ThemeData theme, {
    OtpStyle base = const OtpStyle(),
  }) {
    final ColorScheme scheme = theme.colorScheme;
    final Color text = scheme.onSurface;
    final Color success = Colors.green.shade500;
    final Color error = scheme.error;
    return base.copyWith(
      borderColor: scheme.outlineVariant,
      focusedBorderColor: scheme.primary,
      filledBorderColor: scheme.primary.withValues(alpha: 0.6),
      successBorderColor: success,
      errorBorderColor: error,
      textColor: text,
      processingDotColor: scheme.onPrimary,
      processingTrackColor: scheme.onPrimary.withValues(alpha: 0.25),
      processingHighlightColor: scheme.onPrimary.withValues(alpha: 0.5),
      processingOutlineColor: scheme.onPrimary.withValues(alpha: 0.24),
      processingGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[scheme.primary, scheme.tertiary],
      ),
      successGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[success, Colors.green.shade300],
      ),
      failureGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[error, scheme.errorContainer],
      ),
      glowColor: scheme.primary.withValues(alpha: 0.5),
      resultIconColor: Colors.white,
      textStyle: (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        height: 1,
        color: text,
      ),
    );
  }

  final double boxWidth;
  final double boxHeight;
  final double gap;
  final double idleRadius;
  final double filledRadius;
  final double borderWidth;
  final double focusedBorderWidth;
  final double focusScale;
  final double processingWidthFactor;
  final Color backgroundColor;
  final Color filledBackgroundColor;
  final Color borderColor;
  final Color focusedBorderColor;
  final Color filledBorderColor;
  final Color successBorderColor;
  final Color errorBorderColor;
  final Color textColor;
  final Color processingDotColor;
  final Color processingTrackColor;
  final Color processingHighlightColor;
  final Color processingOutlineColor;
  final LinearGradient processingGradient;
  final LinearGradient successGradient;
  final LinearGradient failureGradient;
  final Color glowColor;
  final Color resultIconColor;
  final TextStyle textStyle;

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
