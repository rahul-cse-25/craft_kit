import 'otp_phase.dart';
import 'otp_render_model.dart';

class OtpStateMachine {
  OtpStateMachine({
    required this.length,
    String initialCode = '',
    bool enabled = true,
  }) : _state = OtpRenderModel(
         code: sanitizeCode(initialCode, length),
         length: length,
         phase: OtpPhase.idle,
         hasFocus: false,
         enabled: enabled,
       );

  final int length;
  OtpRenderModel _state;

  OtpRenderModel get state => _state;

  static String sanitizeCode(String raw, int length) {
    final String normalized = raw.replaceAll(RegExp(r'\D'), '');
    if (normalized.length <= length) {
      return normalized;
    }

    return normalized.substring(0, length);
  }

  OtpRenderModel markEntering() =>
      _update(_state.copyWith(phase: OtpPhase.entering));

  OtpRenderModel settleAfterEntrance() =>
      _update(_state.copyWith(phase: _phaseForCode(_state.code)));

  OtpRenderModel updateFocus(bool hasFocus) =>
      _update(_state.copyWith(hasFocus: hasFocus));

  OtpRenderModel updateEnabled(bool enabled) => _update(
    _state.copyWith(
      enabled: enabled,
      hasFocus: enabled ? _state.hasFocus : false,
    ),
  );

  OtpRenderModel applyCode(String code) {
    if (!_canEdit) {
      return _state;
    }

    final String sanitized = sanitizeCode(code, length);
    return _update(
      _state.copyWith(code: sanitized, phase: _phaseForCode(sanitized)),
    );
  }

  OtpRenderModel deleteOne() {
    if (!_canEdit || _state.code.isEmpty) {
      return _state;
    }

    return applyCode(_state.code.substring(0, _state.code.length - 1));
  }

  OtpRenderModel clear() =>
      _update(_state.copyWith(code: '', phase: OtpPhase.editing));

  OtpRenderModel setCode(String code) {
    final String sanitized = sanitizeCode(code, length);
    return _update(
      _state.copyWith(code: sanitized, phase: _phaseForCode(sanitized)),
    );
  }

  OtpRenderModel markCollapsing() {
    if (!_state.isComplete) {
      return _state;
    }

    return _update(_state.copyWith(phase: OtpPhase.collapsing));
  }

  OtpRenderModel markProcessing() =>
      _update(_state.copyWith(phase: OtpPhase.processing));

  OtpRenderModel markSuccess() =>
      _update(_state.copyWith(phase: OtpPhase.success));

  OtpRenderModel markFailure() =>
      _update(_state.copyWith(phase: OtpPhase.failure));

  OtpRenderModel markRestoring() =>
      _update(_state.copyWith(phase: OtpPhase.restoring));

  OtpRenderModel restore({bool keepCode = true}) {
    final String nextCode = keepCode ? _state.code : '';
    return _update(
      _state.copyWith(code: nextCode, phase: _phaseForCode(nextCode)),
    );
  }

  OtpRenderModel forcePhase(OtpPhase phase) =>
      _update(_state.copyWith(phase: phase));

  bool get _canEdit => _state.enabled && !_state.phase.isBusy;

  OtpPhase _phaseForCode(String code) {
    if (code.length == length) {
      return OtpPhase.complete;
    }

    return OtpPhase.editing;
  }

  OtpRenderModel _update(OtpRenderModel next) {
    _state = next.copyWith(
      code: sanitizeCode(next.code, length),
      length: length,
    );
    return _state;
  }
}
