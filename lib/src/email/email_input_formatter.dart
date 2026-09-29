import 'package:flutter/services.dart'
    show TextInputFormatter, TextEditingValue;
import 'package:flutter/widgets.dart' show TextRange, TextSelection;

/// Normalizes email input as the user types or pastes: lower-cases everything
/// and removes spaces.
///
/// It keeps the cursor in place and works with paste, autofill and IME
/// composition. It does **not** validate the address.
class EmailInputFormatter extends TextInputFormatter {
  /// Creates the formatter.
  const EmailInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String normalized = newValue.text.toLowerCase().replaceAll(' ', '');
    if (normalized == newValue.text) {
      return newValue;
    }

    final TextSelection selection = TextSelection(
      baseOffset: newValue.selection.baseOffset.clamp(0, normalized.length),
      extentOffset: newValue.selection.extentOffset.clamp(0, normalized.length),
    );
    final TextRange composing = newValue.composing;
    final TextRange safeComposing =
        composing.isValid &&
            composing.start >= 0 &&
            composing.end >= composing.start &&
            composing.end <= normalized.length
        ? composing
        : TextRange.empty;

    return newValue.copyWith(
      text: normalized,
      selection: selection,
      composing: safeComposing,
    );
  }
}
