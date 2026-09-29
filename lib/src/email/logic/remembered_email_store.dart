import 'dart:convert';

import '../../storage/craft_storage.dart';
import '../email_validator.dart';
import 'remembered_email_entry.dart';

/// Where remembered emails live.
///
/// Implement it to back the feature with anything (a database, a remote
/// profile). [StorageRememberedEmailStore] is the ready-made implementation on
/// top of a [CraftStorage].
abstract interface class RememberedEmailStore {
  /// Entries ordered most recently used first.
  Future<List<RememberedEmailEntry>> loadEntries();

  /// Records a use of [email]. Invalid addresses are ignored.
  Future<void> rememberEmail(String email);

  /// Removes [email] from the history.
  Future<void> forgetEmail(String email);

  /// Removes the whole history.
  Future<void> clear();
}

/// A [RememberedEmailStore] persisted through a [CraftStorage].
///
/// The history is stored as one JSON list under [storageKey]. Each entry has
/// `email`, `use_count` and `last_used_at_epoch_ms`. Corrupt data is dropped,
/// duplicate emails are merged, and only the [maxEntries] most recent entries
/// survive.
class StorageRememberedEmailStore implements RememberedEmailStore {
  /// Creates a store.
  ///
  /// [isValidEmail] decides what may be persisted; [clock] supplies the
  /// current time (override in tests).
  StorageRememberedEmailStore(
    this._storage, {
    this.maxEntries = 16,
    this.storageKey = 'craft_kit.remembered_emails_v1',
    bool Function(String)? isValidEmail,
    DateTime Function()? clock,
  }) : assert(maxEntries > 0, 'maxEntries must be positive'),
       _isValidEmail = isValidEmail ?? EmailValidator.isValid,
       _clock = clock ?? DateTime.now;

  final CraftStorage _storage;
  final bool Function(String) _isValidEmail;
  final DateTime Function() _clock;

  /// Maximum number of remembered emails.
  final int maxEntries;

  /// Storage key of the history.
  final String storageKey;

  @override
  Future<List<RememberedEmailEntry>> loadEntries() async {
    final String? raw = await _storage.read(storageKey);
    if (raw == null || raw.isEmpty) {
      return const <RememberedEmailEntry>[];
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        await _storage.remove(storageKey);
        return const <RememberedEmailEntry>[];
      }

      final Map<String, RememberedEmailEntry> merged =
          <String, RememberedEmailEntry>{};
      for (final Object? item in decoded) {
        if (item is! Map) continue;
        final RememberedEmailEntry entry = RememberedEmailEntry.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (!_isPersistable(entry.email)) continue;

        final int count = entry.useCount <= 0 ? 1 : entry.useCount;
        final RememberedEmailEntry? existing = merged[entry.email];
        merged[entry.email] = existing == null
            ? entry.copyWith(useCount: count)
            : RememberedEmailEntry(
                email: entry.email,
                useCount: existing.useCount + count,
                lastUsedAtEpochMs:
                    entry.lastUsedAtEpochMs > existing.lastUsedAtEpochMs
                    ? entry.lastUsedAtEpochMs
                    : existing.lastUsedAtEpochMs,
              );
      }

      return _sortAndLimit(merged.values.toList());
    } on FormatException {
      await _storage.remove(storageKey);
      return const <RememberedEmailEntry>[];
    }
  }

  @override
  Future<void> rememberEmail(String email) async {
    final String normalized = EmailValidator.normalize(email);
    if (!_isPersistable(normalized)) return;

    final Map<String, RememberedEmailEntry> byEmail =
        <String, RememberedEmailEntry>{
          for (final RememberedEmailEntry e in await loadEntries()) e.email: e,
        };
    byEmail[normalized] = RememberedEmailEntry(
      email: normalized,
      useCount: (byEmail[normalized]?.useCount ?? 0) + 1,
      lastUsedAtEpochMs: _clock().millisecondsSinceEpoch,
    );
    await _write(_sortAndLimit(byEmail.values.toList()));
  }

  @override
  Future<void> forgetEmail(String email) async {
    final String normalized = EmailValidator.normalize(email);
    final List<RememberedEmailEntry> entries = await loadEntries();
    final List<RememberedEmailEntry> remaining = entries
        .where((RememberedEmailEntry e) => e.email != normalized)
        .toList();
    if (remaining.length == entries.length) return;
    await _write(remaining);
  }

  @override
  Future<void> clear() => _storage.remove(storageKey);

  Future<void> _write(List<RememberedEmailEntry> entries) => _storage.write(
    storageKey,
    jsonEncode(entries.map((RememberedEmailEntry e) => e.toJson()).toList()),
  );

  bool _isPersistable(String email) => email.isNotEmpty && _isValidEmail(email);

  List<RememberedEmailEntry> _sortAndLimit(List<RememberedEmailEntry> entries) {
    entries.sort((RememberedEmailEntry a, RememberedEmailEntry b) {
      final int recency = b.lastUsedAtEpochMs.compareTo(a.lastUsedAtEpochMs);
      if (recency != 0) return recency;
      final int count = b.useCount.compareTo(a.useCount);
      if (count != 0) return count;
      return a.email.compareTo(b.email);
    });
    return entries.length <= maxEntries
        ? entries
        : entries.take(maxEntries).toList();
  }
}
