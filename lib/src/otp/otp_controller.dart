import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Which characters an OTP may contain.
enum OtpInputType {
  /// Digits 0-9 only.
  numeric,

  /// Letters and digits.
  alphanumeric,
}

/// Holds the state of an OTP entry and the logic for cleaning typed, pasted
/// and autofilled input.
///
/// Feed it to an [OtpField]. Other code (for example an SMS-retrieval plugin)
/// can call [setValue] to fill the code programmatically.
class OtpController extends ChangeNotifier {
  /// Creates a controller for a code of [length] characters.
  OtpController({this.length = 6, this.inputType = OtpInputType.numeric})
    : assert(length > 0, 'length must be positive') {
    textController.addListener(_onTextChanged);
  }

  /// Number of characters in the code.
  final int length;

  /// Allowed characters.
  final OtpInputType inputType;

  /// The underlying text controller, used by [OtpField].
  final TextEditingController textController = TextEditingController();

  String _lastNotified = '';

  /// Current code (0..[length] characters).
  String get value => textController.text;

  /// Whether the code has all [length] characters.
  bool get isComplete => value.length == length;

  /// Whether nothing has been entered.
  bool get isEmpty => value.isEmpty;

  /// Extracts an OTP from arbitrary [raw] text (a paste, an SMS body, an
  /// autofill suggestion).
  ///
  /// If [raw] contains a standalone run of exactly [length] valid characters
  /// (like "Your code is 123456."), that run wins. Otherwise all valid
  /// characters are kept, truncated to [length].
  String extractCode(String raw) {
    final run = inputType == OtpInputType.numeric ? r'\d' : r'[A-Za-z0-9]';
    final standalone = RegExp('(?<!$run)$run{$length}(?!$run)');
    final match = standalone.firstMatch(raw);
    if (match != null) return match.group(0)!;
    final allowed = inputType == OtpInputType.numeric
        ? RegExp(r'[^0-9]')
        : RegExp('[^A-Za-z0-9]');
    final cleaned = raw.replaceAll(allowed, '');
    return cleaned.length > length ? cleaned.substring(0, length) : cleaned;
  }

  /// Replaces the code with the cleaned version of [raw].
  void setValue(String raw) {
    final code = extractCode(raw);
    textController.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
  }

  /// Fills the code from the system clipboard. Returns `true` if the
  /// clipboard held usable text.
  Future<bool> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) return false;
    final code = extractCode(text);
    if (code.isEmpty) return false;
    setValue(code);
    return true;
  }

  /// Clears the code.
  void clear() => textController.clear();

  void _onTextChanged() {
    if (textController.text == _lastNotified) return;
    _lastNotified = textController.text;
    notifyListeners();
  }

  @override
  void dispose() {
    textController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }
}
