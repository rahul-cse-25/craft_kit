import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../logic/otp_phase.dart';
import '../logic/otp_render_model.dart';
import '../logic/otp_state_machine.dart';

/// Operations an OTP field exposes to an [OtpCodeController] once attached.
abstract interface class OtpCodeFieldHandle {
  /// Requests keyboard focus for the field.
  void requestFocus();

  /// Removes keyboard focus from the field.
  void unfocus();

  /// Clears the entered code.
  void clear();

  /// Sets the code, already sanitized to the field length.
  void setCode(String code);

  /// Starts the processing animation.
  void beginProcessing();

  /// Shows the success result.
  void showSuccess();

  /// Shows the success result; completes when its animation has finished.
  Future<void> showSuccessAndWait();

  /// Shows the failure result. When [keepCode] is false the code is cleared.
  void showFailure({bool keepCode = true});

  /// Leaves the processing or result state and returns to editing.
  void restoreEditing();
}

/// Reads and drives an OTP field from outside the widget.
///
/// Calls are forwarded to the attached field. While no field is attached they
/// only update the controller state and notify listeners.
class OtpCodeController extends ChangeNotifier {
  /// Creates a controller. Non-digit characters in [initialCode] are dropped.
  OtpCodeController({String initialCode = ''})
    : _code = _looseSanitize(initialCode);

  OtpCodeFieldHandle? _handle;
  String _code;
  OtpPhase _phase = OtpPhase.idle;
  bool _hasFocus = false;
  int? _length;

  /// Current code, digits only.
  String get code => _code;

  /// Current phase of the field.
  OtpPhase get phase => _phase;

  /// Whether the field currently has focus.
  bool get hasFocus => _hasFocus;

  /// Whether a field is attached to this controller.
  bool get isAttached => _handle != null;

  /// Attaches [handle] as the field this controller drives. Called by the field.
  void attach(OtpCodeFieldHandle handle) {
    _handle = handle;
  }

  /// Detaches [handle] if it is the attached field. Called by the field.
  void detach(OtpCodeFieldHandle handle) {
    if (identical(_handle, handle)) {
      _handle = null;
    }
  }

  /// Returns the current code trimmed to [length] digits, for seeding a field.
  String initialCodeFor(int length) =>
      OtpStateMachine.sanitizeCode(_code, length);

  /// Stores the latest state of the field and notifies listeners. Called by
  /// the field.
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
  /// then would dirty an element mid-build and trip a framework assertion.
  ///
  /// The scheduler phase cannot tell us whether that is happening: the very
  /// first build after `runApp` or a hot restart runs outside any frame, so
  /// the phase is idle while the tree is being built. So a snapshot is never
  /// announced synchronously; listeners hear about it at the end of the frame.
  /// The values above are already up to date either way.
  void _notifyWhenSafe() {
    if (_notifyQueued) return;
    _notifyQueued = true;
    final SchedulerBinding binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      _notifyQueued = false;
      if (!_disposed) notifyListeners();
    });
    binding.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Requests focus for the attached field. Does nothing when detached.
  void requestFocus() => _handle?.requestFocus();

  /// Removes focus from the attached field. Does nothing when detached.
  void unfocus() => _handle?.unfocus();

  /// Clears the code.
  void clear() {
    if (_handle != null) {
      _handle!.clear();
      return;
    }

    _applyDetachedCode('');
  }

  /// Sets the code. Non-digits are dropped and the code is cut to the field
  /// length when known.
  void setCode(String code) {
    final String sanitized = _sanitizeForCurrentLength(code);
    if (_handle != null) {
      _handle!.setCode(sanitized);
      return;
    }

    _applyDetachedCode(sanitized);
  }

  /// Starts the processing state, for example while verifying the code.
  void beginProcessing() {
    if (_handle != null) {
      _handle!.beginProcessing();
      return;
    }

    _phase = OtpPhase.processing;
    notifyListeners();
  }

  /// Shows the success result.
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

  /// Shows the failure result. The code is kept unless [keepCode] is false.
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

  /// Leaves processing or a result and returns to editing.
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
