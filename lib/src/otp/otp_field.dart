import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'otp_controller.dart';

/// A row of OTP boxes.
///
/// Input goes through one hidden text field, so all of these work:
/// * typing on the keyboard,
/// * long-press on the boxes to paste the clipboard,
/// * pasting or autofill through the system (`AutofillHints.oneTimeCode`,
///   iOS keyboard suggestion, Android autofill),
/// * setting the value from code via [OtpController.setValue].
///
/// Pasted text is cleaned with [OtpController.extractCode], so "G-123 456"
/// or "Your code is 123456" both become `123456`.
class OtpField extends StatefulWidget {
  /// Creates the field.
  const OtpField({
    super.key,
    required this.controller,
    this.onCompleted,
    this.onChanged,
    this.autofocus = false,
    this.obscureText = false,
    this.enabled = true,
    this.boxSize = const Size(48, 56),
    this.spacing = 8,
    this.borderRadius = 12,
    this.textStyle,
    this.errorText,
  });

  /// Holds the code.
  final OtpController controller;

  /// Called once when all characters have been entered.
  final ValueChanged<String>? onCompleted;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Whether to focus on first build.
  final bool autofocus;

  /// Show dots instead of characters.
  final bool obscureText;

  /// Whether input is accepted.
  final bool enabled;

  /// Size of each box.
  final Size boxSize;

  /// Gap between boxes.
  final double spacing;

  /// Corner radius of each box.
  final double borderRadius;

  /// Style of the characters. Defaults to `titleLarge`.
  final TextStyle? textStyle;

  /// If non-null, boxes turn red and this text is shown below.
  final String? errorText;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final FocusNode _focusNode = FocusNode();
  bool _completedFired = false;

  OtpController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(OtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      _c.addListener(_onChanged);
      _completedFired = false;
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    widget.onChanged?.call(_c.value);
    if (_c.isComplete) {
      if (!_completedFired) {
        _completedFired = true;
        widget.onCompleted?.call(_c.value);
      }
    } else {
      _completedFired = false;
    }
  }

  Future<void> _paste() async {
    await _c.pasteFromClipboard();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = widget.textStyle ?? theme.textTheme.titleLarge;
    final hasError = widget.errorText != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _focusNode.requestFocus : null,
          onLongPress: widget.enabled ? _paste : null,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[_c, _focusNode]),
                builder: (context, _) {
                  final value = _c.value;
                  final active = _focusNode.hasFocus && widget.enabled
                      ? value.length.clamp(0, _c.length - 1)
                      : -1;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (var i = 0; i < _c.length; i++) ...<Widget>[
                        if (i > 0) SizedBox(width: widget.spacing),
                        _OtpBox(
                          size: widget.boxSize,
                          radius: widget.borderRadius,
                          style: style,
                          character: i < value.length ? value[i] : '',
                          obscure: widget.obscureText,
                          isActive: i == active,
                          hasError: hasError,
                          enabled: widget.enabled,
                        ),
                      ],
                    ],
                  );
                },
              ),
              // The real input. Invisible, and sized to cover the boxes.
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _c.textController,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      enabled: widget.enabled,
                      enableInteractiveSelection: false,
                      showCursor: false,
                      autofillHints: const <String>[AutofillHints.oneTimeCode],
                      keyboardType: _c.inputType == OtpInputType.numeric
                          ? TextInputType.number
                          : TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      inputFormatters: <TextInputFormatter>[_OtpFormatter(_c)],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// Cleans every edit. A jump of more than one character (paste, autofill,
/// SMS suggestion) goes through [OtpController.extractCode].
class _OtpFormatter extends TextInputFormatter {
  _OtpFormatter(this.controller);

  final OtpController controller;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final bulk = newValue.text.length - oldValue.text.length > 1;
    final cleaned = bulk
        ? controller.extractCode(newValue.text)
        : controller.extractCode(
            newValue.text.length > controller.length
                ? oldValue.text
                : newValue.text,
          );
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.size,
    required this.radius,
    required this.style,
    required this.character,
    required this.obscure,
    required this.isActive,
    required this.hasError,
    required this.enabled,
  });

  final Size size;
  final double radius;
  final TextStyle? style;
  final String character;
  final bool obscure;
  final bool isActive;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color border = hasError
        ? scheme.error
        : isActive
        ? scheme.primary
        : scheme.outline;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size.width,
      height: size.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? null : scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: isActive ? 2 : 1),
      ),
      child: Text(
        obscure && character.isNotEmpty ? '•' : character,
        style: style,
      ),
    );
  }
}
