import '../email_validator.dart';
import 'remembered_email_entry.dart';

enum EmailSuggestionKind { history, domainCompletion }

class EmailSuggestionItem {
  final String label;
  final String replacementEmail;
  final EmailSuggestionKind kind;

  const EmailSuggestionItem({
    required this.label,
    required this.replacementEmail,
    required this.kind,
  });
}

class EmailSuggestionEngine {
  static const List<String> _defaultCommonDomains = [
    'gmail.com',
    'yahoo.com',
    'outlook.com',
    'hotmail.com',
    'icloud.com',
    'proton.me',
    'protonmail.com',
    'live.com',
    'aol.com',
    'gmx.com',
    'yandex.com',
    'zoho.com',
    'mail.com',
  ];

  final List<String> commonDomains;
  final int maxSuggestions;

  /// Decides whether the typed text is already a complete email (in which
  /// case nothing is suggested). Defaults to [EmailValidator.isValid].
  final bool Function(String) isValidEmail;

  /// Creates an engine. All parameters are optional.
  const EmailSuggestionEngine({
    this.commonDomains = _defaultCommonDomains,
    this.maxSuggestions = 6,
    this.isValidEmail = EmailValidator.isValid,
  });

  List<EmailSuggestionItem> suggest({
    required String rawInput,
    required List<RememberedEmailEntry> rememberedEmails,
  }) {
    final query = rawInput.trim().toLowerCase();
    final queryState = _EmailQueryState.parse(query);
    if (queryState.mode == _EmailQueryMode.blocked ||
        isValidEmail(queryState.fullInput)) {
      return const [];
    }

    switch (queryState.mode) {
      case _EmailQueryMode.historyQuery:
        return _historySuggestions(
          localQuery: queryState.localPart,
          fullQuery: queryState.fullInput,
          rememberedEmails: rememberedEmails,
        );
      case _EmailQueryMode.domainQuery:
        return _domainSuggestions(
          localPart: queryState.localPart,
          domainFragment: queryState.domainFragment,
          rememberedEmails: rememberedEmails,
        );
      case _EmailQueryMode.blocked:
        return const [];
    }
  }

  List<EmailSuggestionItem> _historySuggestions({
    required String localQuery,
    required String fullQuery,
    required List<RememberedEmailEntry> rememberedEmails,
  }) {
    final matches = rememberedEmails
        .where(
          (entry) =>
              _historyMatchRank(entry.email, localQuery, fullQuery) != null,
        )
        .toList(growable: false);

    matches.sort((a, b) {
      final rankA = _historyMatchRank(a.email, localQuery, fullQuery) ?? 99;
      final rankB = _historyMatchRank(b.email, localQuery, fullQuery) ?? 99;
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }

      final countCompare = b.useCount.compareTo(a.useCount);
      if (countCompare != 0) {
        return countCompare;
      }

      final recencyCompare = b.lastUsedAtEpochMs.compareTo(a.lastUsedAtEpochMs);
      if (recencyCompare != 0) {
        return recencyCompare;
      }

      return a.email.compareTo(b.email);
    });

    return matches
        .take(maxSuggestions)
        .map(
          (entry) => EmailSuggestionItem(
            label: entry.email,
            replacementEmail: entry.email,
            kind: EmailSuggestionKind.history,
          ),
        )
        .toList(growable: false);
  }

  List<EmailSuggestionItem> _domainSuggestions({
    required String localPart,
    required String domainFragment,
    required List<RememberedEmailEntry> rememberedEmails,
  }) {
    final rememberedDomains = _aggregateRememberedDomains(rememberedEmails);
    final rememberedMatches = rememberedDomains
        .where(
          (entry) => _domainMatchRank(entry.domain, domainFragment) != null,
        )
        .toList(growable: false);

    rememberedMatches.sort((a, b) {
      final rankA = _domainMatchRank(a.domain, domainFragment) ?? 99;
      final rankB = _domainMatchRank(b.domain, domainFragment) ?? 99;
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }

      final countCompare = b.useCount.compareTo(a.useCount);
      if (countCompare != 0) {
        return countCompare;
      }

      final recencyCompare = b.lastUsedAtEpochMs.compareTo(a.lastUsedAtEpochMs);
      if (recencyCompare != 0) {
        return recencyCompare;
      }

      return a.domain.compareTo(b.domain);
    });

    final suggestions = <EmailSuggestionItem>[];
    final seenEmails = <String>{};

    void addSuggestion(String domain, EmailSuggestionKind kind) {
      final candidate = '$localPart@$domain';
      if (!seenEmails.add(candidate)) {
        return;
      }
      suggestions.add(
        EmailSuggestionItem(
          label: candidate,
          replacementEmail: candidate,
          kind: kind,
        ),
      );
    }

    for (final entry in rememberedMatches) {
      addSuggestion(entry.domain, EmailSuggestionKind.domainCompletion);
      if (suggestions.length >= maxSuggestions) {
        return suggestions;
      }
    }

    for (final domain in commonDomains) {
      if (_domainMatchRank(domain, domainFragment) == null) {
        continue;
      }
      addSuggestion(domain, EmailSuggestionKind.domainCompletion);
      if (suggestions.length >= maxSuggestions) {
        break;
      }
    }

    return suggestions;
  }

  int? _historyMatchRank(String email, String localQuery, String fullQuery) {
    final localPart = email.split('@').first;
    if (localPart.startsWith(localQuery)) {
      return 0;
    }
    if (email.startsWith(fullQuery)) {
      return 1;
    }
    if (localPart.contains(localQuery)) {
      return 2;
    }
    if (email.contains(fullQuery)) {
      return 3;
    }
    return null;
  }

  int? _domainMatchRank(String domain, String domainFragment) {
    if (domain.startsWith(domainFragment)) {
      return 0;
    }
    if (domain.contains(domainFragment)) {
      return 1;
    }
    return null;
  }

  List<_RememberedDomainEntry> _aggregateRememberedDomains(
    List<RememberedEmailEntry> rememberedEmails,
  ) {
    final aggregated = <String, _RememberedDomainEntry>{};
    for (final entry in rememberedEmails) {
      final parts = entry.email.split('@');
      if (parts.length != 2) {
        continue;
      }
      final domain = parts.last;
      final existing = aggregated[domain];
      final latestLastUsedAt =
          existing == null
              ? entry.lastUsedAtEpochMs
              : existing.lastUsedAtEpochMs > entry.lastUsedAtEpochMs
              ? existing.lastUsedAtEpochMs
              : entry.lastUsedAtEpochMs;
      aggregated[domain] = _RememberedDomainEntry(
        domain: domain,
        useCount: (existing?.useCount ?? 0) + entry.useCount,
        lastUsedAtEpochMs: latestLastUsedAt,
      );
    }

    return aggregated.values.toList(growable: false);
  }
}

enum _EmailQueryMode { blocked, historyQuery, domainQuery }

class _EmailQueryState {
  const _EmailQueryState._({
    required this.mode,
    required this.fullInput,
    this.localPart = '',
    this.domainFragment = '',
  });

  final _EmailQueryMode mode;
  final String fullInput;
  final String localPart;
  final String domainFragment;

  factory _EmailQueryState.parse(String input) {
    if (input.isEmpty ||
        input.startsWith('@') ||
        _containsIllegalWhitespace(input)) {
      return _EmailQueryState._(
        mode: _EmailQueryMode.blocked,
        fullInput: input,
      );
    }

    final atMatches = '@'.allMatches(input).length;
    if (atMatches > 1) {
      return _EmailQueryState._(
        mode: _EmailQueryMode.blocked,
        fullInput: input,
      );
    }

    if (atMatches == 0) {
      if (input.length < 2 || !_isValidLocalPartPartial(input)) {
        return _EmailQueryState._(
          mode: _EmailQueryMode.blocked,
          fullInput: input,
        );
      }

      return _EmailQueryState._(
        mode: _EmailQueryMode.historyQuery,
        fullInput: input,
        localPart: input,
      );
    }

    final parts = input.split('@');
    if (parts.length != 2) {
      return _EmailQueryState._(
        mode: _EmailQueryMode.blocked,
        fullInput: input,
      );
    }

    final localPart = parts.first;
    final domainFragment = parts.last;
    if (!_isValidLocalPartPartial(localPart) ||
        domainFragment.isEmpty ||
        !_isValidDomainPartial(domainFragment)) {
      return _EmailQueryState._(
        mode: _EmailQueryMode.blocked,
        fullInput: input,
      );
    }

    return _EmailQueryState._(
      mode: _EmailQueryMode.domainQuery,
      fullInput: input,
      localPart: localPart,
      domainFragment: domainFragment,
    );
  }

  static bool _containsIllegalWhitespace(String input) {
    return input.contains(RegExp(r'\s'));
  }

  static bool _isValidLocalPartPartial(String value) {
    if (value.isEmpty ||
        value.startsWith('.') ||
        value.endsWith('.') ||
        value.contains('..')) {
      return false;
    }

    return RegExp(r'^[a-z0-9._%+\-]+$').hasMatch(value);
  }

  static bool _isValidDomainPartial(String value) {
    if (value.isEmpty || value.startsWith('.') || value.contains('..')) {
      return false;
    }

    if (!RegExp(r'^[a-z0-9.\-]+$').hasMatch(value)) {
      return false;
    }

    final labels = value.split('.');
    for (final label in labels) {
      if (label.isEmpty) {
        continue;
      }
      if (label.startsWith('-') || label.endsWith('-')) {
        return false;
      }
    }

    return true;
  }
}

class _RememberedDomainEntry {
  final String domain;
  final int useCount;
  final int lastUsedAtEpochMs;

  const _RememberedDomainEntry({
    required this.domain,
    required this.useCount,
    required this.lastUsedAtEpochMs,
  });
}
