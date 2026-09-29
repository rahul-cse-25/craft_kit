import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../logic/otp_phase.dart';
import '../logic/otp_render_model.dart';
import '../logic/otp_state_machine.dart';

abstract interface class OtpCodeFieldHandle {
  void requestFocus();
  void unfocus();
  void clear();
  void setCode(String code);
  void beginProcessing();
  void showSuccess();
  Future<void> showSuccessAndWait();
  void showFailure({bool keepCode = true});
  void restoreEditing();
}

class OtpCodeController extends ChangeNotifier {
  OtpCodeController({String initialCode = ''})
    : _code = _looseSanitize(initialCode);

  OtpCodeFieldHandle? _handle;
  String _code;
  OtpPhase _phase = OtpPhase.idle;
  bool _hasFocus = false;
  int? _length;

  String get code => _code;

  OtpPhase get phase => _phase;

  bool get hasFocus => _hasFocus;

  bool get isAttached => _handle != null;

  void attach(OtpCodeFieldHandle handle) {
    _handle = handle;
  }

  void detach(OtpCodeFieldHandle handle) {
    if (identical(_handle, handle)) {
      _handle = null;
    }
  }

  String initialCodeFor(int length) =>
      OtpStateMachine.sanitizeCode(_code, length);

  void updateSnapshot(OtpRenderModel snapshot) {
    _length = snapshot.length;
    _code = snapshot.code;
    _phase = snapshot.phase;
    _hasFocus = snapshot.hasFocus;
    _notifyWhenSafe();
  }

  bool _notifyQueued = false;
  bool _disposed = false;

  /// The field publishes snapshots from `initState` and `didUpdateWidget`,
  /// which run while the tree is building. A listener that calls `setState`
  /// then would dirty an element mid-build and trip a framework assertion. So
  /// during the build/layout/paint phase, notification waits for the end of
  /// the frame. The values above are already up to date either way.
  void _notifyWhenSafe() {
    final SchedulerBinding binding = SchedulerBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_notifyQueued) return;
    _notifyQueued = true;
    binding.addPostFrameCallback((_) {
      _notifyQueued = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void requestFocus() => _handle?.requestFocus();

  void unfocus() => _handle?.unfocus();

  void clear() {
    if (_handle != null) {
      _handle!.clear();
      return;
    }

    _applyDetachedCode('');
  }

  void setCode(String code) {
    final String sanitized = _sanitizeForCurrentLength(code);
    if (_handle != null) {
      _handle!.setCode(sanitized);
      return;
    }

    _applyDetachedCode(sanitized);
  }

  void beginProcessing() {
    if (_handle != null) {
      _handle!.beginProcessing();
      return;
    }

    _phase = OtpPhase.processing;
    notifyListeners();
  }

  void showSuccess() {
    if (_handle != null) {
      _handle!.showSuccess();
      return;
    }

    _phase = OtpPhase.success;
    notifyListeners();
  }

  /// Like [showSuccess], but the returned future completes once the success
  /// animation has finished, so a caller can wait before navigating away.
  ///
  /// It completes immediately when there is nothing to animate (no field is
  /// attached, or the code is empty).
  Future<void> showSuccessAndWait() async {
    if (_handle != null) {
      await _handle!.showSuccessAndWait();
      return;
    }

    _phase = OtpPhase.success;
    notifyListeners();
  }

  void showFailure({bool keepCode = true}) {
    if (_handle != null) {
      _handle!.showFailure(keepCode: keepCode);
      return;
    }

    if (!keepCode) {
      _code = '';
    }
    _phase = keepCode ? OtpPhase.complete : OtpPhase.editing;
    notifyListeners();
  }

  void restoreEditing() {
    if (_handle != null) {
      _handle!.restoreEditing();
      return;
    }

    _phase = _resolveEditingPhase(_code);
    notifyListeners();
  }

  void _applyDetachedCode(String code) {
    _code = code;
    _phase = _resolveEditingPhase(code);
    notifyListeners();
  }

  String _sanitizeForCurrentLength(String code) {
    if (_length == null) {
      return _looseSanitize(code);
    }

    return OtpStateMachine.sanitizeCode(code, _length!);
  }

  OtpPhase _resolveEditingPhase(String code) {
    if (_length != null && code.length == _length) {
      return OtpPhase.complete;
    }

    return OtpPhase.editing;
  }

  static String _looseSanitize(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}
