import 'package:flutter/foundation.dart';

/// One remembered email with the usage data used to rank suggestions.
@immutable
class RememberedEmailEntry {
  /// Creates an entry.
  const RememberedEmailEntry({
    required this.email,
    required this.useCount,
    required this.lastUsedAtEpochMs,
  });

  /// Reads an entry from its stored form. Missing or malformed fields fall
  /// back to safe values; the email is trimmed and lower-cased.
  factory RememberedEmailEntry.fromJson(Map<String, dynamic> json) {
    final Object? rawEmail = json['email'];
    final Object? rawUseCount = json['use_count'];
    final Object? rawLastUsedAt = json['last_used_at_epoch_ms'];

    return RememberedEmailEntry(
      email: (rawEmail is String ? rawEmail : '').trim().toLowerCase(),
      useCount: rawUseCount is num ? rawUseCount.toInt() : 0,
      lastUsedAtEpochMs: rawLastUsedAt is num ? rawLastUsedAt.toInt() : 0,
    );
  }

  /// Normalized (lower-case) email address.
  final String email;

  /// How many times the address has been remembered.
  final int useCount;

  /// Milliseconds since epoch of the latest use.
  final int lastUsedAtEpochMs;

  /// The stored form. The keys are a stable, persisted format.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': email,
    'use_count': useCount,
    'last_used_at_epoch_ms': lastUsedAtEpochMs,
  };

  /// Copy with some fields replaced.
  RememberedEmailEntry copyWith({
    String? email,
    int? useCount,
    int? lastUsedAtEpochMs,
  }) {
    return RememberedEmailEntry(
      email: email ?? this.email,
      useCount: useCount ?? this.useCount,
      lastUsedAtEpochMs: lastUsedAtEpochMs ?? this.lastUsedAtEpochMs,
    );
  }
}
