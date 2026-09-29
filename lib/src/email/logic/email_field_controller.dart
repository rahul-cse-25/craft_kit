import 'dart:async';

import 'package:flutter/widgets.dart';

import 'email_suggestion_engine.dart';
import 'remembered_email_entry.dart';
import 'remembered_email_store.dart';

/// Owns an email field's text, focus and live suggestions.
///
/// It has no UI. Bind [textController] and [focusNode] to any text field and
/// listen to [suggestions] to render chips (or use `EmailSuggestionsView` and
/// `RememberedEmailField`).
///
/// Suggestions only show while the field has focus and [suggestionsEnabled] is
/// true, so a screen can hide them while another step (like an OTP sheet) is
/// active.
class EmailFieldController {
  /// Creates a controller that reads history from [store].
  ///
  /// Pass [textController] or [focusNode] to reuse existing ones; the
  /// controller then does not dispose them.
  EmailFieldController({
    required RememberedEmailStore store,
    EmailSuggestionEngine engine = const EmailSuggestionEngine(),
    TextEditingController? textController,
    FocusNode? focusNode,
  }) : // Named parameters cannot be private, so no initializing formals.
       // ignore: prefer_initializing_formals
       _store = store,
       // ignore: prefer_initializing_formals
       _engine = engine,
       _ownsTextController = textController == null,
       _ownsFocusNode = focusNode == null,
       textController = textController ?? TextEditingController(),
       focusNode = focusNode ?? FocusNode() {
    this.textController.addListener(_refreshSuggestions);
    this.focusNode.addListener(_refreshSuggestions);
    unawaited(_reloadEntries());
  }

  final RememberedEmailStore _store;
  final EmailSuggestionEngine _engine;
  final bool _ownsTextController;
  final bool _ownsFocusNode;

  /// Text of the field. Bind it to your text field.
  final TextEditingController textController;

  /// Focus of the field. Bind it to your text field.
  final FocusNode focusNode;

  /// Current suggestions.
  final ValueNotifier<List<EmailSuggestionItem>> suggestions =
      ValueNotifier<List<EmailSuggestionItem>>(const <EmailSuggestionItem>[]);

  List<RememberedEmailEntry> _entries = const <RememberedEmailEntry>[];
  bool _suggestionsEnabled = true;
  bool _isDisposed = false;

  /// The trimmed text.
  String get email => textController.text.trim();

  /// Whether suggestions may be shown.
  bool get suggestionsEnabled => _suggestionsEnabled;

  set suggestionsEnabled(bool value) {
    if (_suggestionsEnabled == value) return;
    _suggestionsEnabled = value;
    _refreshSuggestions();
  }

  /// Replaces the text, moving the cursor to the end.
  void setEmail(String? value) {
    final String next = value?.trim() ?? '';
    if (textController.text == next) return;
    textController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  /// Focuses the field, optionally selecting all text.
  void requestFocus({bool selectAll = false}) {
    focusNode.requestFocus();
    final String text = textController.text;
    if (!selectAll || text.isEmpty) return;
    textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  }

  /// Removes focus.
  void unfocus() => focusNode.unfocus();

  /// Puts [suggestion] into the field and keeps focus.
  void selectSuggestion(EmailSuggestionItem suggestion) {
    if (!_suggestionsEnabled) return;
    setEmail(suggestion.replacementEmail);
    focusNode.requestFocus();
  }

  /// Remembers the current text.
  Future<void> rememberCurrentEmail() => rememberEmail(email);

  /// Remembers [email] and refreshes suggestions.
  Future<void> rememberEmail(String email) async {
    await _store.rememberEmail(email);
    await _reloadEntries();
  }

  /// Forgets [email] and refreshes suggestions.
  Future<void> forgetEmail(String email) async {
    await _store.forgetEmail(email);
    await _reloadEntries();
  }

  /// Releases resources.
  void dispose() {
    _isDisposed = true;
    textController.removeListener(_refreshSuggestions);
    focusNode.removeListener(_refreshSuggestions);
    if (_ownsTextController) textController.dispose();
    if (_ownsFocusNode) focusNode.dispose();
    suggestions.dispose();
  }

  Future<void> _reloadEntries() async {
    final List<RememberedEmailEntry> entries = await _store.loadEntries();
    if (_isDisposed) return;
    _entries = entries;
    _refreshSuggestions();
  }

  void _refreshSuggestions() {
    if (_isDisposed) return;
    final List<EmailSuggestionItem> next =
        !focusNode.hasFocus || !_suggestionsEnabled
            ? const <EmailSuggestionItem>[]
            : _engine.suggest(
              rawInput: textController.text,
              rememberedEmails: _entries,
            );
    if (_same(suggestions.value, next)) return;
    suggestions.value = next;
  }

  bool _same(List<EmailSuggestionItem> a, List<EmailSuggestionItem> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].replacementEmail != b[i].replacementEmail ||
          a[i].kind != b[i].kind ||
          a[i].label != b[i].label) {
        return false;
      }
    }
    return true;
  }
}
