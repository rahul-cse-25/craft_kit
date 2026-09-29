import 'dart:convert';

import 'package:craft_kit/craft_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryCraftStorage storage;
  late DateTime now;
  late StorageRememberedEmailStore store;

  StorageRememberedEmailStore build({int maxEntries = 16}) =>
      StorageRememberedEmailStore(
        storage,
        maxEntries: maxEntries,
        storageKey: 'k',
        clock: () => now,
      );

  setUp(() {
    storage = MemoryCraftStorage();
    now = DateTime.fromMillisecondsSinceEpoch(1000);
    store = build();
  });

  test('starts empty', () async {
    expect(await store.loadEntries(), isEmpty);
  });

  test('normalizes, counts uses and refreshes recency', () async {
    await store.rememberEmail('  Anna@Example.COM ');
    now = DateTime.fromMillisecondsSinceEpoch(2000);
    await store.rememberEmail('anna@example.com');

    final entries = await store.loadEntries();
    expect(entries, hasLength(1));
    expect(entries.single.email, 'anna@example.com');
    expect(entries.single.useCount, 2);
    expect(entries.single.lastUsedAtEpochMs, 2000);
  });

  test('ignores invalid emails', () async {
    await store.rememberEmail('nope');
    await store.rememberEmail('');
    expect(await store.loadEntries(), isEmpty);
  });

  test('orders most recent first and caps at maxEntries', () async {
    final capped = build(maxEntries: 2);
    for (var i = 1; i <= 3; i++) {
      now = DateTime.fromMillisecondsSinceEpoch(i * 1000);
      await capped.rememberEmail('u$i@x.co');
    }
    final emails = (await capped.loadEntries()).map((e) => e.email);
    expect(emails, ['u3@x.co', 'u2@x.co']);
  });

  test('forgetEmail and clear', () async {
    await store.rememberEmail('a@x.co');
    now = DateTime.fromMillisecondsSinceEpoch(2000);
    await store.rememberEmail('b@x.co');

    await store.forgetEmail('A@X.co');
    expect((await store.loadEntries()).map((e) => e.email), ['b@x.co']);

    await store.clear();
    expect(await store.loadEntries(), isEmpty);
  });

  test('reads the legacy JSON format and merges duplicates', () async {
    await storage.write(
      'k',
      jsonEncode([
        {'email': 'A@x.co', 'use_count': 2, 'last_used_at_epoch_ms': 10},
        {'email': 'a@x.co', 'use_count': 0, 'last_used_at_epoch_ms': 30},
        {'email': 'bad', 'use_count': 5, 'last_used_at_epoch_ms': 99},
        'not a map',
      ]),
    );
    final entries = await store.loadEntries();
    expect(entries, hasLength(1));
    expect(entries.single.email, 'a@x.co');
    expect(entries.single.useCount, 3); // 2 + (0 counts as 1)
    expect(entries.single.lastUsedAtEpochMs, 30);
  });

  test('drops corrupt data instead of throwing', () async {
    await storage.write('k', '{not json');
    expect(await store.loadEntries(), isEmpty);
    expect(await storage.read('k'), isNull);

    await storage.write('k', '{"a":1}'); // valid JSON, wrong shape
    expect(await store.loadEntries(), isEmpty);
    expect(await storage.read('k'), isNull);
  });

  test('reports discarded data through onCorruptData', () async {
    final reported = <Object>[];
    final watching = StorageRememberedEmailStore(
      storage,
      storageKey: 'k',
      onCorruptData: (error, stack) => reported.add(error),
    );

    await storage.write('k', '{not json');
    expect(await watching.loadEntries(), isEmpty);
    expect(reported, hasLength(1));

    await storage.write('k', '{"a":1}'); // valid JSON, wrong shape
    expect(await watching.loadEntries(), isEmpty);
    expect(reported, hasLength(2));

    await watching.rememberEmail('a@x.co'); // healthy data reports nothing
    await watching.loadEntries();
    expect(reported, hasLength(2));
  });

  test('accepts a custom validator', () async {
    final strict = StorageRememberedEmailStore(
      storage,
      storageKey: 'k',
      isValidEmail: (e) => e.endsWith('@corp.com'),
    );
    await strict.rememberEmail('a@x.co');
    await strict.rememberEmail('a@corp.com');
    expect((await strict.loadEntries()).map((e) => e.email), ['a@corp.com']);
  });
}
