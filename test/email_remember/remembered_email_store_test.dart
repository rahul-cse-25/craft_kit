import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmailValidator', () {
    test('accepts common addresses', () {
      expect(EmailValidator.isValid('a@b.co'), isTrue);
      expect(
        EmailValidator.isValid('  first.last+tag@sub.example.com '),
        isTrue,
      );
    });

    test('rejects malformed addresses', () {
      for (final bad in ['', 'a', 'a@', '@b.co', 'a@b', 'a b@c.com', null]) {
        expect(EmailValidator.isValid(bad), isFalse, reason: '$bad');
      }
    });
  });

  group('RememberedEmailStore', () {
    late MemoryCraftStorage storage;
    late RememberedEmailStore store;

    setUp(() async {
      storage = MemoryCraftStorage();
      store = RememberedEmailStore(storage: storage, maxEntries: 3);
      await store.load();
    });

    test('does not save unless remember is enabled', () async {
      expect(await store.rememberIfEnabled('a@b.co'), isFalse);
      expect(store.emails, isEmpty);
    });

    test(
      'saves most recent first and de-duplicates case-insensitively',
      () async {
        await store.setRememberEnabled(true);
        await store.rememberIfEnabled('a@b.co');
        await store.rememberIfEnabled('c@d.co');
        await store.rememberIfEnabled('A@B.co');
        expect(store.emails, ['A@B.co', 'c@d.co']);
        expect(store.lastEmail, 'A@B.co');
      },
    );

    test('caps at maxEntries, dropping the oldest', () async {
      await store.setRememberEnabled(true);
      for (final e in ['1@x.co', '2@x.co', '3@x.co', '4@x.co']) {
        await store.remember(e);
      }
      expect(store.emails, ['4@x.co', '3@x.co', '2@x.co']);
    });

    test('ignores invalid emails', () async {
      await store.setRememberEnabled(true);
      expect(await store.remember('nope'), isFalse);
      expect(store.emails, isEmpty);
    });

    test('forget and clear', () async {
      await store.setRememberEnabled(true);
      await store.remember('a@b.co');
      await store.remember('c@d.co');
      await store.forget('A@B.CO');
      expect(store.emails, ['c@d.co']);
      await store.clear();
      expect(store.emails, isEmpty);
      expect(store.rememberEnabled, isTrue);
    });

    test('disabling remember wipes saved emails', () async {
      await store.setRememberEnabled(true);
      await store.remember('a@b.co');
      await store.setRememberEnabled(false);
      expect(store.emails, isEmpty);
    });

    test('suggestions filter by substring and hide exact match', () async {
      await store.setRememberEnabled(true);
      await store.remember('anna@x.co');
      await store.remember('bob@x.co');
      expect(store.suggestions(''), ['bob@x.co', 'anna@x.co']);
      expect(store.suggestions('AN'), ['anna@x.co']);
      expect(store.suggestions('bob@x.co'), isEmpty);
    });

    test('persists and reloads', () async {
      await store.setRememberEnabled(true);
      await store.remember('a@b.co');
      final reloaded = RememberedEmailStore(storage: storage, maxEntries: 3);
      await reloaded.load();
      expect(reloaded.rememberEnabled, isTrue);
      expect(reloaded.emails, ['a@b.co']);
    });

    test('survives corrupt storage', () async {
      await storage.write('craft_kit.remembered_emails', '{not json');
      final s = RememberedEmailStore(storage: storage);
      await s.load();
      expect(s.isLoaded, isTrue);
      expect(s.emails, isEmpty);
    });
  });

  testWidgets('RememberEmailField prefills and toggles remember', (
    tester,
  ) async {
    final storage = MemoryCraftStorage();
    final seed = RememberedEmailStore(storage: storage);
    await seed.load();
    await seed.setRememberEnabled(true);
    await seed.remember('saved@x.co');

    final store = RememberedEmailStore(storage: storage);
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RememberEmailField(store: store)),
      ),
    );
    expect(find.text('saved@x.co'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(store.rememberEnabled, isFalse);
  });
}
