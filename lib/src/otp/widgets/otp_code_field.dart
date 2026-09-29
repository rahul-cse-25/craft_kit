import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../animation/otp_animation_coordinator.dart';
import '../animation/otp_animation_spec.dart';
import '../controller/otp_code_controller.dart';
import '../logic/otp_input_coordinator.dart';
import '../logic/otp_phase.dart';
import '../logic/otp_state_machine.dart';
import '../style/otp_haptics.dart';
import '../style/otp_labels.dart';
import '../style/otp_style.dart';
import 'otp_digit_box.dart';
import 'otp_processing_box.dart';

/// An animated one-time-code input.
///
/// Typing, paste, long-press delete, and system autofill all go through one
/// hidden text input, so digits always land sequentially. Drive the
/// verification animation (collapse, processing, success, failure) through an
/// [OtpCodeController].
class OtpCodeField extends StatefulWidget {
  /// Creates the field.
  const OtpCodeField({
    super.key,
    this.length = 6,
    this.controller,
    this.onChanged,
    this.onCompleted,
    this.autoFocus = true,
    this.enabled = true,
    this.allowPaste = true,
    this.style,
    this.haptics = const OtpHaptics(),
    this.animationSpec = const OtpAnimationSpec(),
    this.labels = const OtpLabels(),
    this.semanticsLabel,
  }) : assert(length > 0, 'OTP length must be greater than 0.');

  /// Number of digits.
  final int length;

  /// Optional controller to drive the field from outside.
  final OtpCodeController? controller;

  /// Called whenever the code changes.
  final ValueChanged<String>? onChanged;

  /// Called once when all [length] digits are present.
  final ValueChanged<String>? onCompleted;

  /// Focus the field after the entrance animation starts.
  final bool autoFocus;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether text selection (and therefore the paste menu) is available.
  final bool allowPaste;

  /// Look of the field. When null it is derived from the ambient [Theme];
  /// pass `const OtpStyle()` for the dark-surface look.
  final OtpStyle? style;

  /// Haptic feedback on success and failure. Use `null` entries to disable.
  final OtpHaptics haptics;

  /// Durations and curves.
  final OtpAnimationSpec animationSpec;

  /// Accessibility strings; override to localize.
  final OtpLabels labels;

  /// Overrides [OtpLabels.inputLabel] only.
  final String? semanticsLabel;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField>
    with TickerProviderStateMixin, WidgetsBindingObserver
    implements OtpCodeFieldHandle {
  late final OtpCodeController _fallbackController;
  late OtpCodeController _boundController;
  final GlobalKey<EditableTextState> _editableTextKey =
      GlobalKey<EditableTextState>();
  late TextEditingController _textController;
  late FocusNode _focusNode;
  late OtpInputCoordinator _inputCoordinator;
  late OtpStateMachine _stateMachine;
  late OtpAnimationCoordinator _animationCoordinator;

  late OtpStyle _style;
  Timer? _deleteTimer;
  bool _isSyncingText = false;
  bool _wantsFocusWhenInteractive = false;
  bool _shouldRestoreFocusOnResume = false;
  String? _lastCompletedCode;
  int _transitionToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fallbackController = OtpCodeController();
    _boundController = widget.controller ?? _fallbackController;
    _stateMachine = OtpStateMachine(
      length: widget.length,
      initialCode: _boundController.initialCodeFor(widget.length),
      enabled: widget.enabled,
    );
    _inputCoordinator = OtpInputCoordinator(
      length: widget.length,
      allowPaste: widget.allowPaste,
    );
    _animationCoordinator = OtpAnimationCoordinator(
      vsync: this,
      spec: widget.animationSpec,
      length: widget.length,
    );
    _textController = TextEditingController(text: _stateMachine.state.code);
    _focusNode = FocusNode(debugLabel: 'OtpCodeField');
    _focusNode.addListener(_handleFocusChanged);
    _boundController.attach(this);
    _boundController.updateSnapshot(_stateMachine.state);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _startEntranceFlow();
    });
  }

  @override
  void didUpdateWidget(covariant OtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool shouldRebuild = false;

    if (widget.length != oldWidget.length) {
      final bool hadFocus = _focusNode.hasFocus;
      final String preservedCode = OtpStateMachine.sanitizeCode(
        _stateMachine.state.code,
        widget.length,
      );
      _stateMachine = OtpStateMachine(
        length: widget.length,
        initialCode: preservedCode,
        enabled: widget.enabled,
      );
      if (hadFocus && widget.enabled) {
        _stateMachine.updateFocus(true);
      }
      _stateMachine.forcePhase(
        preservedCode.length == widget.length
            ? OtpPhase.complete
            : OtpPhase.editing,
      );
      _inputCoordinator = OtpInputCoordinator(
        length: widget.length,
        allowPaste: widget.allowPaste,
      );
      _animationCoordinator.updateSpec(
        spec: widget.animationSpec,
        length: widget.length,
      );
      _lastCompletedCode = null;
      shouldRebuild = true;
    } else if (widget.allowPaste != oldWidget.allowPaste) {
      _inputCoordinator = OtpInputCoordinator(
        length: widget.length,
        allowPaste: widget.allowPaste,
      );
    }

    if (widget.enabled != oldWidget.enabled) {
      if (!widget.enabled) {
        _focusNode.unfocus();
      }
      _stateMachine.updateEnabled(widget.enabled);
      shouldRebuild = true;
    }

    if (!identical(widget.controller, oldWidget.controller)) {
      _boundController.detach(this);
      _boundController = widget.controller ?? _fallbackController;
      _boundController.attach(this);
      _stateMachine.setCode(_boundController.initialCodeFor(widget.length));
      shouldRebuild = true;
    }

    if (widget.animationSpec != oldWidget.animationSpec ||
        widget.length != oldWidget.length) {
      _animationCoordinator.updateSpec(
        spec: widget.animationSpec,
        length: widget.length,
      );
    }

    if (shouldRebuild) {
      _syncTextController();
      _boundController.updateSnapshot(_stateMachine.state);
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deleteTimer?.cancel();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _textController.dispose();
    _animationCoordinator.dispose();
    _boundController.detach(this);
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _shouldRestoreFocusOnResume =
            _wantsFocusWhenInteractive &&
            widget.enabled &&
            !_stateMachine.state.phase.isBusy;
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
        break;
      case AppLifecycleState.resumed:
        if (_shouldRestoreFocusOnResume) {
          _shouldRestoreFocusOnResume = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            Future<void>.delayed(const Duration(milliseconds: 120), () {
              if (!mounted || !_wantsFocusWhenInteractive) {
                return;
              }
              _requestFocus();
            });
          });
        }
        break;
    }
  }

  // Cached in didChangeDependencies. Reading MediaQuery lazily from a
  // post-frame callback or an awaited animation is unsafe: the element may
  // already be deactivated (for example when a TabBarView swaps pages).
  bool _disableAnimations = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      _stopDeleteLoop();
      final AppLifecycleState? lifecycleState =
          WidgetsBinding.instance.lifecycleState;
      final bool appIsInteractive =
          lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
      if (appIsInteractive) {
        _wantsFocusWhenInteractive = false;
      }
    } else if (widget.enabled && !_stateMachine.state.phase.isBusy) {
      _wantsFocusWhenInteractive = true;
    }

    _stateMachine.updateFocus(_focusNode.hasFocus);
    _publishState(notifyChanged: false, notifyCompleted: false);
  }

  void _handleTextChanged() {
    if (_isSyncingText) {
      return;
    }

    final String previousCode = _stateMachine.state.code;
    final OtpInputUpdate update = _inputCoordinator.handleRawText(
      previousCode: previousCode,
      rawText: _textController.text,
    );

    _stateMachine.applyCode(update.code);
    _publishState(
      previousCode: previousCode,
      notifyChanged: previousCode != _stateMachine.state.code,
      notifyCompleted: true,
    );
  }

  void _publishState({
    String? previousCode,
    required bool notifyChanged,
    required bool notifyCompleted,
  }) {
    _syncTextController();
    _boundController.updateSnapshot(_stateMachine.state);

    if (notifyChanged &&
        previousCode != null &&
        previousCode != _stateMachine.state.code) {
      widget.onChanged?.call(_stateMachine.state.code);
    }

    if (notifyCompleted && previousCode != null) {
      _maybeDispatchCompletion(
        previousCode: previousCode,
        nextCode: _stateMachine.state.code,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _maybeDispatchCompletion({
    required String previousCode,
    required String nextCode,
  }) {
    if (nextCode.length < widget.length) {
      _lastCompletedCode = null;
      return;
    }

    if (nextCode.length == widget.length && nextCode != _lastCompletedCode) {
      _lastCompletedCode = nextCode;
      widget.onCompleted?.call(nextCode);
    }
  }

  void _syncTextController() {
    final String nextText = _stateMachine.state.code;
    final TextSelection nextSelection = TextSelection.collapsed(
      offset: nextText.length,
    );

    if (_textController.text == nextText &&
        _textController.selection == nextSelection) {
      return;
    }

    _isSyncingText = true;
    _textController.value = TextEditingValue(
      text: nextText,
      selection: nextSelection,
    );
    _isSyncingText = false;
  }

  void _startEntranceFlow() {
    _stateMachine.markEntering();
    _publishState(notifyChanged: false, notifyCompleted: false);

    if (widget.autoFocus && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _requestFocus();
        }
      });
    }

    final int token = ++_transitionToken;
    unawaited(_runEntrance(token));
  }

  Future<void> _runEntrance(int token) async {
    await _animationCoordinator.playEntrance(
      disableAnimations: _disableAnimations,
    );
    if (!_isCurrentTransition(token)) {
      return;
    }

    _stateMachine.settleAfterEntrance();
    _publishState(notifyChanged: false, notifyCompleted: false);
  }

  bool _isCurrentTransition(int token) => mounted && token == _transitionToken;

  void _requestFocus() {
    if (!widget.enabled || _stateMachine.state.phase.isBusy) {
      return;
    }

    _wantsFocusWhenInteractive = true;
    final EditableTextState? editableText = _editableTextKey.currentState;
    if (editableText != null) {
      editableText.requestKeyboard();
      return;
    }

    _focusNode.requestFocus();
  }

  void _triggerHaptic(OtpHapticType? type) {
    if (type == null) {
      return;
    }

    unawaited(type.perform());
  }

  bool get _canLoopDelete =>
      widget.enabled &&
      _stateMachine.state.code.isNotEmpty &&
      !_stateMachine.state.phase.isBusy;

  void _startDeleteLoop() {
    if (!_canLoopDelete) {
      return;
    }

    _requestFocus();
    _deleteOne();
    _deleteTimer?.cancel();
    _deleteTimer = Timer(widget.animationSpec.deleteRepeatInitialDelay, () {
      if (!mounted) {
        return;
      }

      _deleteTimer = Timer.periodic(widget.animationSpec.deleteRepeatInterval, (
        _,
      ) {
        if (!_canLoopDelete) {
          _stopDeleteLoop();
          return;
        }

        _deleteOne();
      });
    });
  }

  void _stopDeleteLoop() {
    _deleteTimer?.cancel();
    _deleteTimer = null;
  }

  void _deleteOne() {
    if (!_canLoopDelete) {
      return;
    }

    final String previousCode = _stateMachine.state.code;
    final String nextCode = _inputCoordinator.handleBackspace(previousCode);
    _stateMachine.applyCode(nextCode);
    _publishState(
      previousCode: previousCode,
      notifyChanged: previousCode != _stateMachine.state.code,
      notifyCompleted: true,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        event is KeyRepeatEvent) {
      _deleteOne();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void requestFocus() => _requestFocus();

  @override
  void unfocus() {
    _wantsFocusWhenInteractive = false;
    _focusNode.unfocus();
  }

  @override
  void clear() {
    _transitionToken++;
    _stopDeleteLoop();
    _animationCoordinator.resetArtifacts();
    final String previousCode = _stateMachine.state.code;
    _stateMachine.clear();
    _publishState(
      previousCode: previousCode,
      notifyChanged: previousCode.isNotEmpty,
      notifyCompleted: true,
    );

    if (widget.enabled) {
      _requestFocus();
    }
  }

  @override
  void setCode(String code) {
    _transitionToken++;
    _stopDeleteLoop();
    _animationCoordinator.stopProcessingLoop();
    _animationCoordinator.resultController.reset();
    _animationCoordinator.collapseController.value = 0;
    final String previousCode = _stateMachine.state.code;
    _stateMachine.setCode(_inputCoordinator.handlePaste(code));
    _publishState(
      previousCode: previousCode,
      notifyChanged: previousCode != _stateMachine.state.code,
      notifyCompleted: true,
    );
  }

  @override
  void beginProcessing() {
    if (!_stateMachine.state.isComplete ||
        _stateMachine.state.phase == OtpPhase.processing ||
        _stateMachine.state.phase == OtpPhase.success) {
      return;
    }

    _wantsFocusWhenInteractive = false;
    _stopDeleteLoop();
    _focusNode.unfocus();
    _animationCoordinator.stopProcessingLoop();
    _animationCoordinator.resultController.reset();
    final int token = ++_transitionToken;
    _stateMachine.markCollapsing();
    _publishState(notifyChanged: false, notifyCompleted: false);
    unawaited(_runProcessing(token));
  }

  Future<void> _runProcessing(int token) async {
    await _animationCoordinator.playCollapse(
      disableAnimations: _disableAnimations,
    );
    if (!_isCurrentTransition(token)) {
      return;
    }

    _stateMachine.markProcessing();
    _publishState(notifyChanged: false, notifyCompleted: false);
    _animationCoordinator.startProcessingLoop(
      disableAnimations: _disableAnimations,
    );
  }

  @override
  void showSuccess() {
    unawaited(showSuccessAndWait());
  }

  @override
  Future<void> showSuccessAndWait() async {
    if (_stateMachine.state.code.isEmpty) {
      return;
    }

    _wantsFocusWhenInteractive = false;
    _stopDeleteLoop();
    _focusNode.unfocus();
    final int token = ++_transitionToken;
    await _runSuccess(token);
  }

  Future<void> _runSuccess(int token) async {
    _animationCoordinator.stopProcessingLoop(reset: false);
    if (_animationCoordinator.collapseController.value < 1) {
      await _animationCoordinator.playCollapse(
        disableAnimations: _disableAnimations,
      );
    }
    if (!_isCurrentTransition(token)) {
      return;
    }

    _stateMachine.markSuccess();
    _triggerHaptic(widget.haptics.success);
    _publishState(notifyChanged: false, notifyCompleted: false);
    await _animationCoordinator.playSuccess(
      disableAnimations: _disableAnimations,
    );
  }

  @override
  void showFailure({bool keepCode = true}) {
    if (_stateMachine.state.code.isEmpty) {
      return;
    }

    _wantsFocusWhenInteractive = false;
    _stopDeleteLoop();
    final int token = ++_transitionToken;
    unawaited(_runFailure(token, keepCode: keepCode));
  }

  Future<void> _runFailure(int token, {required bool keepCode}) async {
    _focusNode.unfocus();
    _animationCoordinator.stopProcessingLoop(reset: false);
    if (_animationCoordinator.collapseController.value < 1) {
      await _animationCoordinator.playCollapse(
        disableAnimations: _disableAnimations,
      );
    }
    if (!_isCurrentTransition(token)) {
      return;
    }

    _stateMachine.markFailure();
    _triggerHaptic(widget.haptics.failure);
    _publishState(notifyChanged: false, notifyCompleted: false);
    await _animationCoordinator.playFailure(
      disableAnimations: _disableAnimations,
    );
    if (!_isCurrentTransition(token)) {
      return;
    }

    _stateMachine.markRestoring();
    _publishState(notifyChanged: false, notifyCompleted: false);
    await _animationCoordinator.playRestore(
      disableAnimations: _disableAnimations,
    );
    if (!_isCurrentTransition(token)) {
      return;
    }

    final String previousCode = _stateMachine.state.code;
    _stateMachine.restore(keepCode: keepCode);
    _publishState(
      previousCode: previousCode,
      notifyChanged: !keepCode,
      notifyCompleted: false,
    );

    if (widget.enabled) {
      _requestFocus();
    }
  }

  @override
  void restoreEditing() {
    final int token = ++_transitionToken;
    unawaited(_runRestore(token));
  }

  Future<void> _runRestore(int token) async {
    _stopDeleteLoop();
    _animationCoordinator.stopProcessingLoop();
    if (_animationCoordinator.collapseController.value > 0) {
      _stateMachine.markRestoring();
      _publishState(notifyChanged: false, notifyCompleted: false);
      await _animationCoordinator.playRestore(
        disableAnimations: _disableAnimations,
      );
      if (!_isCurrentTransition(token)) {
        return;
      }
    }

    _stateMachine.restore();
    _publishState(notifyChanged: false, notifyCompleted: false);

    if (widget.enabled) {
      _requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _style = widget.style ?? OtpStyle.fromTheme(Theme.of(context));
        final OtpStyle style = _style;
        final double baseRowWidth = _baseRowWidth(style);
        final double baseCanvasHeight = _baseCanvasHeight(style);
        final double responsiveScale = _resolveResponsiveScale(
          constraints: constraints,
          rowWidth: baseRowWidth,
        );
        final double viewportWidth = baseRowWidth * responsiveScale;
        final double viewportHeight = baseCanvasHeight * responsiveScale;
        final String semanticsValue = widget.labels.valueBuilder(
          _stateMachine.state.filledCount,
          widget.length,
        );

        return Semantics(
          textField: true,
          enabled: widget.enabled,
          focused: _stateMachine.state.hasFocus,
          label: widget.semanticsLabel ?? widget.labels.inputLabel,
          value: semanticsValue,
          hint:
              _stateMachine.state.code.isNotEmpty
                  ? widget.labels.filledHint
                  : widget.labels.emptyHint,
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: _handleKeyEvent,
            child: MouseRegion(
              cursor:
                  widget.enabled && !_stateMachine.state.phase.isBusy
                      ? SystemMouseCursors.text
                      : SystemMouseCursors.basic,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap:
                    widget.enabled && !_stateMachine.state.phase.isBusy
                        ? _requestFocus
                        : null,
                onLongPressStart:
                    _canLoopDelete ? (_) => _startDeleteLoop() : null,
                onLongPressEnd:
                    _canLoopDelete ? (_) => _stopDeleteLoop() : null,
                onLongPressCancel: _stopDeleteLoop,
                child: RepaintBoundary(
                  child: SizedBox(
                    width: viewportWidth,
                    height: viewportHeight,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: baseRowWidth,
                        height: baseCanvasHeight,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox(
                                    width: 1,
                                    height: 1,
                                    child: AutofillGroup(
                                      child: EditableText(
                                        key: _editableTextKey,
                                        controller: _textController,
                                        focusNode: _focusNode,
                                        showCursor: false,
                                        autofocus: false,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.done,
                                        inputFormatters: <TextInputFormatter>[
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(
                                            widget.length,
                                          ),
                                        ],
                                        autofillHints: const <String>[
                                          AutofillHints.oneTimeCode,
                                        ],
                                        readOnly:
                                            !widget.enabled ||
                                            _stateMachine.state.phase.isBusy,
                                        autocorrect: false,
                                        enableSuggestions: false,
                                        enableInteractiveSelection:
                                            widget.allowPaste,
                                        style: const TextStyle(
                                          color: Colors.transparent,
                                          fontSize: 1,
                                          height: 1,
                                        ),
                                        cursorColor: Colors.transparent,
                                        backgroundCursorColor:
                                            Colors.transparent,
                                        selectionColor: Colors.transparent,
                                        onChanged: (_) => _handleTextChanged(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation:
                                  _animationCoordinator.repaintListenable,
                              builder: (BuildContext context, Widget? child) {
                                return _buildAnimatedSurface(
                                  context: context,
                                  rowWidth: baseRowWidth,
                                  canvasHeight: baseCanvasHeight,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _baseRowWidth(OtpStyle style) {
    return (style.boxWidth * widget.length) + (style.gap * (widget.length - 1));
  }

  double _baseCanvasHeight(OtpStyle style) =>
      style.boxHeight + style.canvasVerticalPadding;

  double _resolveResponsiveScale({
    required BoxConstraints constraints,
    required double rowWidth,
  }) {
    final double maxWidth = constraints.maxWidth;
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return 1;
    }

    return math.min(1, maxWidth / rowWidth);
  }

  Widget _buildAnimatedSurface({
    required BuildContext context,
    required double rowWidth,
    required double canvasHeight,
  }) {
    final OtpStyle style = _style;
    final OtpPhase phase = _stateMachine.state.phase;
    final double rawCollapse = _animationCoordinator.collapseController.value;
    final double collapse = widget.animationSpec.collapseCurve.transform(
      rawCollapse.clamp(0.0, 1.0),
    );
    final double processingValue = _animationCoordinator
        .processingController
        .value
        .clamp(0.0, 1.0);
    final double resultValue = _animationCoordinator.resultController.value
        .clamp(0.0, 1.0);
    final double capsuleOpacity = switch (phase) {
      OtpPhase.collapsing => ((collapse - 0.18) / 0.82).clamp(0.0, 1.0),
      OtpPhase.processing ||
      OtpPhase.success ||
      OtpPhase.failure ||
      OtpPhase.restoring => collapse.clamp(0.0, 1.0),
      _ => 0.0,
    };
    final double failureShake =
        phase == OtpPhase.failure
            ? math.sin(resultValue * math.pi * 6) * (1 - resultValue) * 10
            : 0;
    final int? focusedIndex = _stateMachine.state.focusedIndex;
    final double spacing = style.boxWidth + style.gap;
    final double center = (widget.length - 1) / 2;

    return SizedBox(
      width: rowWidth,
      height: canvasHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          OtpProcessingBoxView(
            phase: phase,
            opacity: capsuleOpacity,
            size: Size(style.boxWidth, style.boxHeight),
            height: style.boxHeight,
            processingValue: processingValue,
            resultValue: resultValue,
            style: style,
            animationSpec: widget.animationSpec,
            horizontalShake: failureShake,
          ),
          for (int index = 0; index < widget.length; index++)
            _buildDigitBox(
              index: index,
              spacing: spacing,
              center: center,
              rowWidth: rowWidth,
              collapse: collapse,
              capsuleOpacity: capsuleOpacity,
              failureShake: failureShake,
              focusedIndex: focusedIndex,
            ),
        ],
      ),
    );
  }

  Widget _buildDigitBox({
    required int index,
    required double spacing,
    required double center,
    required double rowWidth,
    required double collapse,
    required double capsuleOpacity,
    required double failureShake,
    required int? focusedIndex,
  }) {
    final OtpStyle style = _style;
    final double baseOffset = (index - center) * spacing;
    final double entranceProgress = _animationCoordinator
        .entranceProgressFor(index)
        .clamp(0.0, 1.0);
    final double entranceDx =
        ui.lerpDouble(
          -rowWidth * 0.30 - ((widget.length - index) * 8),
          0,
          entranceProgress,
        ) ??
        0;
    final double entranceDy =
        ui.lerpDouble(
          28 + ((widget.length - index) * 4.5),
          0,
          entranceProgress,
        ) ??
        0;
    final double translationX =
        (baseOffset * (1 - collapse)) + entranceDx + failureShake;
    final double translationY = entranceDy - (collapse * 2.5);
    final bool isFilled = index < _stateMachine.state.filledCount;
    final bool isFocused =
        focusedIndex == index && !_stateMachine.state.phase.isBusy;
    final String digit = isFilled ? _stateMachine.state.code[index] : '';
    final double boxOpacityFactor = switch (_stateMachine.state.phase) {
      OtpPhase.processing ||
      OtpPhase.success ||
      OtpPhase.failure => (1 - capsuleOpacity).clamp(0.0, 0.02),
      OtpPhase.restoring => (1 - capsuleOpacity).clamp(0.0, 1.0),
      _ => 1 - (capsuleOpacity * 0.94),
    };

    return Transform.translate(
      offset: Offset(translationX, translationY),
      child: OtpDigitBoxView(
        digit: digit,
        isFilled: isFilled,
        isFocused: isFocused,
        enabled: widget.enabled,
        opacity: entranceProgress * boxOpacityFactor,
        phase: _stateMachine.state.phase,
        style: style,
        animationSpec: widget.animationSpec,
        disableAnimations: _disableAnimations,
      ),
    );
  }
}
