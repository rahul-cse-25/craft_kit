import 'package:flutter/foundation.dart';

@immutable
class OtpInputUpdate {
  const OtpInputUpdate({
    required this.code,
    required this.isDeletion,
    required this.isPasteLike,
  });

  final String code;
  final bool isDeletion;
  final bool isPasteLike;
}

class OtpInputCoordinator {
  OtpInputCoordinator({required this.length, required this.allowPaste});

  final int length;
  final bool allowPaste;

  static const Map<int, String> _localizedDigits = <int, String>{
    0x0660: '0',
    0x0661: '1',
    0x0662: '2',
    0x0663: '3',
    0x0664: '4',
    0x0665: '5',
    0x0666: '6',
    0x0667: '7',
    0x0668: '8',
    0x0669: '9',
    0x06F0: '0',
    0x06F1: '1',
    0x06F2: '2',
    0x06F3: '3',
    0x06F4: '4',
    0x06F5: '5',
    0x06F6: '6',
    0x06F7: '7',
    0x06F8: '8',
    0x06F9: '9',
  };

  OtpInputUpdate handleRawText({
    required String previousCode,
    required String rawText,
  }) {
    final String normalized = normalizeDigits(rawText);
    return OtpInputUpdate(
      code: normalized,
      isDeletion: normalized.length < previousCode.length,
      isPasteLike: normalized.length - previousCode.length > 1,
    );
  }

  String handleBackspace(String code) {
    if (code.isEmpty) {
      return code;
    }

    return code.substring(0, code.length - 1);
  }

  String handlePaste(String text) => normalizeDigits(text);

  /// Reduces arbitrary text (typed, pasted, autofilled) to at most [length]
  /// ASCII digits.
  ///
  /// If [text] holds more digits than [length] and contains a standalone run
  /// of exactly [length] digits (for example "Order 22, code 654321"), that
  /// run wins. Otherwise every digit is kept in order, so "123 456" and
  /// "12-34-56" both become "123456". Arabic-Indic and Persian digits are
  /// converted to ASCII.
  String normalizeDigits(String text) {
    final String ascii = _toAsciiDigits(text);
    final RegExpMatch? standalone = RegExp(
      '(?<![0-9])[0-9]{$length}(?![0-9])',
    ).firstMatch(ascii);
    if (standalone != null &&
        ascii.replaceAll(RegExp(r'[^0-9]'), '').length > length) {
      return standalone.group(0)!;
    }
    return _keepDigits(ascii);
  }

  String _toAsciiDigits(String text) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in text.runes) {
      buffer.write(_normalizeRune(rune) ?? String.fromCharCode(rune));
    }
    return buffer.toString();
  }

  String _keepDigits(String text) {
    final StringBuffer buffer = StringBuffer();

    for (final int rune in text.runes) {
      final String? normalizedDigit = _normalizeRune(rune);
      if (normalizedDigit == null) {
        continue;
      }

      buffer.write(normalizedDigit);
      if (buffer.length >= length) {
        break;
      }
    }

    return buffer.toString();
  }

  String? _normalizeRune(int rune) {
    if (rune >= 0x30 && rune <= 0x39) {
      return String.fromCharCode(rune);
    }

    return _localizedDigits[rune];
  }
}
