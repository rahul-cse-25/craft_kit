import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../storage/craft_storage.dart';
import 'email_validator.dart';

/// Stores emails the user chose to remember and exposes them as suggestions.
///
/// Behavior:
/// * The most recently used email comes first.
/// * Emails are de-duplicated case-insensitively.
/// * At most [maxEntries] emails are kept; the oldest are dropped.
/// * A "remember me" flag ([rememberEnabled]) controls whether
///   [rememberIfEnabled] saves anything.
///
/// Call [load] once before use, then listen to the store to rebuild UI.
class RememberedEmailStore extends ChangeNotifier {
  /// Creates a store backed by [storage] (in-memory by default).
  RememberedEmailStore({
    CraftStorage? storage,
    this.maxEntries = 5,
    this.storageKey = 'craft_kit.remembered_emails',
  }) : assert(maxEntries > 0, 'maxEntries must be positive'),
       _storage = storage ?? MemoryCraftStorage();

  final CraftStorage _storage;

  /// Maximum number of emails to keep.
  final int maxEntries;

  /// Key under which the state is persisted.
  final String storageKey;

  List<String> _emails = <String>[];
  bool _rememberEnabled = false;
  bool _loaded = false;

  /// Whether [load] has completed.
  bool get isLoaded => _loaded;

  /// Whether the user opted in to remembering emails.
  bool get rememberEnabled => _rememberEnabled;

  /// Remembered emails, most recent first.
  List<String> get emails => List<String>.unmodifiable(_emails);

  /// The most recently remembered email, if any.
  String? get lastEmail => _emails.isEmpty ? null : _emails.first;

  /// Reads persisted state. Corrupt data is ignored.
  Future<void> load() async {
    try {
      final raw = await _storage.read(storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _rememberEnabled = decoded['enabled'] == true;
          final list = decoded['emails'];
          if (list is List) {
            _emails = list
                .whereType<String>()
                .where(EmailValidator.isValid)
                .take(maxEntries)
                .toList();
          }
        }
      }
    } on FormatException {
      _emails = <String>[];
      _rememberEnabled = false;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Turns "remember me" on or off. Turning it off also clears saved emails.
  Future<void> setRememberEnabled(bool enabled) async {
    if (_rememberEnabled == enabled) return;
    _rememberEnabled = enabled;
    if (!enabled) _emails = <String>[];
    notifyListeners();
    await _persist();
  }

  /// Remembers [email] if "remember me" is enabled and the email is valid.
  ///
  /// Returns `true` if it was saved.
  Future<bool> rememberIfEnabled(String email) async {
    if (!_rememberEnabled) return false;
    return remember(email);
  }

  /// Remembers [email] regardless of [rememberEnabled]. Returns `true` if
  /// saved (the email was valid).
  Future<bool> remember(String email) async {
    if (!EmailValidator.isValid(email)) return false;
    final trimmed = email.trim();
    final key = EmailValidator.normalize(trimmed);
    _emails
      ..removeWhere((e) => EmailValidator.normalize(e) == key)
      ..insert(0, trimmed);
    if (_emails.length > maxEntries) {
      _emails = _emails.sublist(0, maxEntries);
    }
    notifyListeners();
    await _persist();
    return true;
  }

  /// Removes a single remembered [email].
  Future<void> forget(String email) async {
    final key = EmailValidator.normalize(email);
    final before = _emails.length;
    _emails.removeWhere((e) => EmailValidator.normalize(e) == key);
    if (_emails.length == before) return;
    notifyListeners();
    await _persist();
  }

  /// Removes all remembered emails (keeps the "remember me" flag).
  Future<void> clear() async {
    if (_emails.isEmpty) return;
    _emails = <String>[];
    notifyListeners();
    await _persist();
  }

  /// Emails containing [query] (case-insensitive), most recent first. An empty
  /// query returns all emails. An exact match is hidden since it adds nothing.
  List<String> suggestions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return emails;
    return _emails.where((e) {
      final lower = e.toLowerCase();
      return lower.contains(q) && lower != q;
    }).toList();
  }

  Future<void> _persist() => _storage.write(
    storageKey,
    jsonEncode(<String, Object>{
      'enabled': _rememberEnabled,
      'emails': _emails,
    }),
  );
}
