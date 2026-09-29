import 'package:craft_kit/craft_kit.dart';
import 'package:flutter_test/flutter_test.dart';

RememberedEmailEntry entry(String email, {int uses = 1, int at = 0}) =>
    RememberedEmailEntry(email: email, useCount: uses, lastUsedAtEpochMs: at);

void main() {
  const engine = EmailSuggestionEngine();

  List<String> labels(String input, List<RememberedEmailEntry> history) =>
      engine
          .suggest(rawInput: input, rememberedEmails: history)
          .map((s) => s.label)
          .toList();

  group('blocked input', () {
    test('shows nothing for empty, one char, leading @, spaces, two @', () {
      final history = [entry('anna@gmail.com')];
      for (final input in ['', 'a', '@gm', 'an na', 'a@b@c']) {
        expect(labels(input, history), isEmpty, reason: input);
      }
    });

    test('shows nothing once the email is complete', () {
      expect(labels('anna@gmail.com', [entry('anna@gmail.com')]), isEmpty);
    });
  });

  group('history (no @ typed yet)', () {
    test('matches local-part prefix first, then contains', () {
      final history = [
        entry('xanna@a.com', at: 3),
        entry('anna@b.com', at: 1),
        entry('bob@c.com', at: 2),
      ];
      expect(labels('an', history), ['anna@b.com', 'xanna@a.com']);
    });

    test('ties are broken by use count, then recency', () {
      final history = [
        entry('ann1@a.com', uses: 1, at: 9),
        entry('ann2@a.com', uses: 5, at: 1),
      ];
      expect(labels('ann', history), ['ann2@a.com', 'ann1@a.com']);
    });

    test('caps at maxSuggestions', () {
      final history = [for (var i = 0; i < 10; i++) entry('user$i@a.com')];
      const small = EmailSuggestionEngine(maxSuggestions: 3);
      expect(
        small.suggest(rawInput: 'us', rememberedEmails: history),
        hasLength(3),
      );
    });

    test('items are tagged as history', () {
      final s = engine.suggest(
        rawInput: 'an',
        rememberedEmails: [entry('anna@a.com')],
      );
      expect(s.single.kind, EmailSuggestionKind.history);
      expect(s.single.replacementEmail, 'anna@a.com');
    });
  });

  group('domain completion (after @)', () {
    test('completes common domains', () {
      expect(labels('anna@gm', const []), ['anna@gmail.com', 'anna@gmx.com']);
    });

    test('remembered domains come before common ones', () {
      final history = [entry('bob@gmwork.io', uses: 3)];
      expect(labels('anna@gm', history).first, 'anna@gmwork.io');
    });

    test('items are tagged as domain completions', () {
      final s = engine.suggest(rawInput: 'anna@gm', rememberedEmails: const []);
      expect(s.first.kind, EmailSuggestionKind.domainCompletion);
    });

    test('does not repeat a candidate', () {
      final history = [entry('bob@gmail.com')];
      final out = labels('anna@gmail', history);
      expect(out.toSet().length, out.length);
    });
  });

  test('a custom validator decides what is "complete"', () {
    final lenient = EmailSuggestionEngine(isValidEmail: (_) => false);
    // With nothing ever "complete", a full address still yields suggestions.
    expect(
      lenient.suggest(rawInput: 'anna@gmail.com', rememberedEmails: const []),
      isNotEmpty,
    );
  });
}
