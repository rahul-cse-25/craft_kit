// ignore_for_file: public_member_api_docs (internal, not exported)

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../animation/otp_animation_spec.dart';
import '../logic/otp_phase.dart';
import '../style/otp_style.dart';

class OtpProcessingBoxView extends StatelessWidget {
  const OtpProcessingBoxView({
    super.key,
    required this.phase,
    required this.opacity,
    required this.size,
    required this.height,
    required this.processingValue,
    required this.resultValue,
    required this.style,
    required this.animationSpec,
    required this.horizontalShake,
  });

  final OtpPhase phase;
  final double opacity;
  final Size size;
  final double height;
  final double processingValue;
  final double resultValue;
  final OtpStyle style;
  final OtpAnimationSpec animationSpec;
  final double horizontalShake;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) {
      return const SizedBox.shrink();
    }

    final double pulse = animationSpec.processingCurve.transform(
      (0.5 + (math.sin(processingValue * math.pi * 2) * 0.5)).clamp(0.0, 1.0),
    );
    final double successScale =
        phase == OtpPhase.success ? 0.98 + (resultValue * 0.10) : 1;
    final double failureScale =
        phase == OtpPhase.failure ? 1 + ((1 - resultValue) * 0.015) : 1;
    final double processingScale = switch (phase) {
      OtpPhase.processing ||
      OtpPhase.collapsing ||
      OtpPhase.restoring => 0.985 + (pulse * 0.05),
      _ => 1,
    };
    final LinearGradient gradient = switch (phase) {
      OtpPhase.success => style.successGradient,
      OtpPhase.failure => style.failureGradient,
      _ => style.processingGradient,
    };
    final bool followGradient =
        style.resultGlow == OtpResultGlow.followGradient;
    // Classic (the default) keeps one glow color and softer result glow;
    // followGradient tints the result glow with the gradient's middle color.
    final Color phaseGlowColor = switch (phase) {
      OtpPhase.success || OtpPhase.failure when followGradient =>
        gradient.colors[gradient.colors.length ~/ 2],
      _ => style.glowColor,
    };
    final double glowOpacity = switch (phase) {
      OtpPhase.success => (followGradient ? 0.34 : 0.28) + (resultValue * 0.12),
      OtpPhase.failure =>
        (followGradient ? 0.28 : 0.18) +
            ((1 - resultValue) * (followGradient ? 0.10 : 0.08)),
      _ => 0.18 + (pulse * 0.22),
    };
    final double outlineOpacity = switch (phase) {
      OtpPhase.success => 0.46,
      OtpPhase.failure => 0.34,
      _ => 0.22 + (pulse * 0.16),
    };
    final double liveAngle = (processingValue * math.pi * 2) % (math.pi * 2);
    final double diamondAngle = math.pi / 4;
    final double flowingAngle = switch (phase) {
      OtpPhase.processing ||
      OtpPhase.collapsing ||
      OtpPhase.restoring => liveAngle,
      OtpPhase.success || OtpPhase.failure =>
        ui.lerpDouble(
              liveAngle,
              diamondAngle,
              Curves.easeOutCubic.transform(resultValue.clamp(0.0, 1.0)),
            ) ??
            diamondAngle,
      _ => diamondAngle,
    };
    final double borderRadius =
        ui.lerpDouble(
          style.filledRadius,
          style.filledRadius + 2,
          switch (phase) {
            OtpPhase.processing => pulse,
            OtpPhase.success => resultValue,
            OtpPhase.failure => 1 - resultValue,
            _ => 0,
          },
        ) ??
        style.filledRadius;

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(horizontalShake, 0),
          child: Transform.scale(
            scale: processingScale * successScale * failureScale,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(borderRadius + 8),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: phaseGlowColor.withValues(
                              alpha: glowOpacity,
                            ),
                            blurRadius: 26 + (pulse * 20),
                            spreadRadius: 1.2 + (pulse * 1.8),
                          ),
                          BoxShadow(
                            color: gradient.colors.first.withValues(
                              alpha: 0.08 + (pulse * 0.12),
                            ),
                            blurRadius: 18,
                            spreadRadius: 0.4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: flowingAngle,
                    child: CustomPaint(
                      size: size,
                      painter: OtpFlowBorderPainter(
                        borderRadius: borderRadius,
                        gradient: gradient,
                        outlineColor: style.processingOutlineColor.withValues(
                          alpha: outlineOpacity,
                        ),
                        flashColor: style.processingHighlightColor.withValues(
                          alpha: 0.16 + (pulse * 0.12),
                        ),
                        isAnimated: switch (phase) {
                          OtpPhase.processing ||
                          OtpPhase.collapsing ||
                          OtpPhase.restoring => true,
                          _ => false,
                        },
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                    ),
                  ),
                  _buildContent(gradient),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(LinearGradient gradient) {
    switch (phase) {
      case OtpPhase.success:
        return OtpResultGlyph(
          icon: Icons.check_rounded,
          iconColor: style.resultIconColor,
          progress: resultValue,
          tintedShadow: style.resultGlow == OtpResultGlow.followGradient,
        );
      case OtpPhase.failure:
        return OtpResultGlyph(
          icon: Icons.close_rounded,
          iconColor: style.resultIconColor,
          progress: resultValue,
          tintedShadow: style.resultGlow == OtpResultGlow.followGradient,
        );
      default:
        return OtpCircularLoader(
          size: math.min(height * 0.48, 28),
          angle: processingValue * math.pi * 2,
          color: style.processingDotColor,
          trackColor: style.processingTrackColor,
        );
    }
  }
}

class OtpCircularLoader extends StatelessWidget {
  const OtpCircularLoader({
    super.key,
    required this.size,
    required this.angle,
    required this.color,
    required this.trackColor,
  });

  final double size;
  final double angle;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Transform.rotate(
            angle: angle,
            child: CustomPaint(
              size: Size.square(size),
              painter: OtpCircularLoaderPainter(
                color: color,
                trackColor: trackColor,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.94),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 8,
                  spreadRadius: 0.4,
                ),
              ],
            ),
            child: SizedBox.square(dimension: size * 0.18),
          ),
        ],
      ),
    );
  }
}

class OtpFlowBorderPainter extends CustomPainter {
  const OtpFlowBorderPainter({
    required this.borderRadius,
    required this.gradient,
    required this.outlineColor,
    required this.flashColor,
    required this.isAnimated,
  });

  final double borderRadius;
  final LinearGradient gradient;
  final Color outlineColor;
  final Color flashColor;
  final bool isAnimated;

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 2.2;
    final Rect rect = Offset.zero & size;
    final RRect border = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );
    final Color leadColor = _sampleGradientColor(0.18);
    final Color midColor = _sampleGradientColor(0.50);
    final Color tailColor = _sampleGradientColor(0.82);
    final Color seamColor = _sampleGradientColor(0.04);

    final Paint outlinePaint =
        Paint()
          ..color = outlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    final Paint borderPaint =
        Paint()
          ..shader = SweepGradient(
            colors: <Color>[
              seamColor,
              midColor,
              tailColor,
              leadColor,
              seamColor,
            ],
            stops: const <double>[0.0, 0.34, 0.66, 0.88, 1.0],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    final List<Color> glowColors =
        isAnimated
            ? <Color>[
              Colors.transparent,
              flashColor.withValues(alpha: 0.22),
              flashColor,
              flashColor.withValues(alpha: 0.14),
              Colors.transparent,
            ]
            : <Color>[
              Colors.transparent,
              flashColor.withValues(alpha: 0.18),
              flashColor,
              Colors.transparent,
            ];
    final List<double> glowStops =
        isAnimated
            ? const <double>[0.0, 0.10, 0.18, 0.28, 1.0]
            : const <double>[0.0, 0.26, 0.50, 1.0];

    final Paint glowPaint =
        Paint()
          ..shader = SweepGradient(
            colors: glowColors,
            stops: glowStops,
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 0.4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    canvas.drawRRect(border, outlinePaint);
    canvas.drawRRect(border, borderPaint);
    canvas.drawRRect(border, glowPaint);
  }

  Color _sampleGradientColor(double t) {
    final List<Color> colors = gradient.colors;
    if (colors.isEmpty) {
      return Colors.white;
    }
    if (colors.length == 1) {
      return colors.first;
    }

    final List<double> stops =
        gradient.stops ??
        List<double>.generate(
          colors.length,
          (int index) => index / (colors.length - 1),
        );

    final double clampedT = t.clamp(0.0, 1.0);
    for (int index = 0; index < stops.length - 1; index++) {
      final double start = stops[index];
      final double end = stops[index + 1];
      if (clampedT > end && index < stops.length - 2) {
        continue;
      }

      final double segmentT =
          end == start
              ? 0.0
              : ((clampedT - start) / (end - start)).clamp(0.0, 1.0);
      return Color.lerp(colors[index], colors[index + 1], segmentT) ??
          colors[index];
    }

    return colors.last;
  }

  @override
  bool shouldRepaint(covariant OtpFlowBorderPainter oldDelegate) {
    return borderRadius != oldDelegate.borderRadius ||
        gradient != oldDelegate.gradient ||
        outlineColor != oldDelegate.outlineColor ||
        flashColor != oldDelegate.flashColor ||
        isAnimated != oldDelegate.isAnimated;
  }
}

class OtpCircularLoaderPainter extends CustomPainter {
  const OtpCircularLoaderPainter({
    required this.color,
    required this.trackColor,
  });

  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 2.5;
    final Rect rect = Offset.zero & size;
    final Rect arcRect = rect.deflate(strokeWidth / 2);

    final Paint trackPaint =
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    final Paint progressPaint =
        Paint()
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: (math.pi * 3) / 2,
            colors: <Color>[
              color.withValues(alpha: 0.0),
              color.withValues(alpha: 0.24),
              color,
              color.withValues(alpha: 0.10),
            ],
            stops: const <double>[0.0, 0.26, 0.72, 1.0],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, 0, math.pi * 2, false, trackPaint);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 1.58, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant OtpCircularLoaderPainter oldDelegate) {
    return color != oldDelegate.color || trackColor != oldDelegate.trackColor;
  }
}

class OtpResultGlyph extends StatelessWidget {
  const OtpResultGlyph({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.progress,
    this.tintedShadow = false,
  });

  final IconData icon;
  final Color iconColor;
  final double progress;

  /// Shadow uses [iconColor] instead of white.
  final bool tintedShadow;

  @override
  Widget build(BuildContext context) {
    final double eased = Curves.easeOutBack.transform(progress.clamp(0.0, 1.0));
    return Transform.scale(
      scale: 0.84 + (eased * 0.18),
      child: Icon(
        icon,
        color: iconColor,
        size: icon == Icons.check_rounded ? 28 : 26,
        shadows: <Shadow>[
          if (tintedShadow)
            Shadow(color: iconColor.withValues(alpha: 0.34), blurRadius: 10)
          else
            Shadow(color: Colors.white.withValues(alpha: 0.20), blurRadius: 12),
        ],
      ),
    );
  }
}
