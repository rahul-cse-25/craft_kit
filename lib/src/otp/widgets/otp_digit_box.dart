// ignore_for_file: public_member_api_docs (internal, not exported)

import 'package:flutter/material.dart';

import '../animation/otp_animation_spec.dart';
import '../logic/otp_phase.dart';
import '../style/otp_style.dart';

class OtpDigitBoxView extends StatelessWidget {
  const OtpDigitBoxView({
    super.key,
    required this.digit,
    required this.isFilled,
    required this.isFocused,
    required this.enabled,
    required this.opacity,
    required this.phase,
    required this.style,
    required this.animationSpec,
    required this.disableAnimations,
  });

  final String digit;
  final bool isFilled;
  final bool isFocused;
  final bool enabled;
  final double opacity;
  final OtpPhase phase;
  final OtpStyle style;
  final OtpAnimationSpec animationSpec;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final Duration fillDuration =
        disableAnimations ? Duration.zero : animationSpec.fillDuration;
    final Duration focusDuration =
        disableAnimations ? Duration.zero : animationSpec.focusDuration;
    final Color borderColor = switch (phase) {
      OtpPhase.failure => style.errorBorderColor,
      OtpPhase.success => style.successBorderColor,
      _ when isFocused => style.focusedBorderColor,
      _ when isFilled => style.filledBorderColor,
      _ => style.borderColor,
    };
    final Color backgroundColor =
        isFilled ? style.filledBackgroundColor : style.backgroundColor;
    final List<BoxShadow> shadow =
        isFocused && enabled
            ? <BoxShadow>[
              BoxShadow(
                color: style.focusedBorderColor.withValues(alpha: 0.24),
                blurRadius: 22,
                spreadRadius: 0.6,
              ),
              if (isFilled)
                BoxShadow(
                  color: style.filledBorderColor.withValues(alpha: 0.10),
                  blurRadius: 16,
                  spreadRadius: -0.5,
                ),
            ]
            : isFilled && enabled
            ? <BoxShadow>[
              BoxShadow(
                color: style.filledBorderColor.withValues(alpha: 0.11),
                blurRadius: 14,
                spreadRadius: -0.6,
              ),
            ]
            : const <BoxShadow>[];

    return Opacity(
      opacity: enabled ? opacity : opacity * 0.64,
      child: AnimatedScale(
        scale: enabled && isFocused ? style.focusScale : 1,
        duration: focusDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: fillDuration,
          curve: Curves.easeOutCubic,
          width: style.boxWidth,
          height: style.boxHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(
              isFilled ? style.filledRadius : style.idleRadius,
            ),
            border: Border.all(
              color: borderColor,
              width: isFocused ? style.focusedBorderWidth : style.borderWidth,
            ),
            boxShadow: shadow,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: fillDuration,
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.86,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child:
                  digit.isEmpty
                      ? const SizedBox.shrink(key: ValueKey<String>('empty'))
                      : Text(
                        digit,
                        key: ValueKey<String>(digit),
                        style: style.textStyle.copyWith(
                          color:
                              enabled
                                  ? style.textColor
                                  : style.textColor.withValues(alpha: 0.58),
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
