import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<EmailFieldController> controllerWith(
  StorageRememberedEmailStore store,
) async {
  final c = EmailFieldController(store: store);
  // Let the initial load finish. Microtasks only: timers never fire inside
  // testWidgets' fake-async zone, so Future.delayed would hang there.
  for (var i = 0; i < 20; i++) {
    await Future<void>.value();
  }
  return c;
}

void main() {
  late StorageRememberedEmailStore store;

  setUp(() async {
    store = StorageRememberedEmailStore(MemoryCraftStorage());
    await store.rememberEmail('anna@example.com');
  });

  group('EmailFieldController', () {
    testWidgets('suggests only while focused', (tester) async {
      final c = await controllerWith(store);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: c.textController,
              focusNode: c.focusNode,
            ),
          ),
        ),
      );

      c.textController.text = 'an';
      expect(c.suggestions.value, isEmpty); // no focus yet

      c.focusNode.requestFocus();
      await tester.pump();
      expect(c.suggestions.value.map((s) => s.label), ['anna@example.com']);

      c.unfocus();
      await tester.pump();
      expect(c.suggestions.value, isEmpty);
    });

    testWidgets('suggestionsEnabled hides suggestions', (tester) async {
      final c = await controllerWith(store);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: c.textController,
              focusNode: c.focusNode,
            ),
          ),
        ),
      );
      c.focusNode.requestFocus();
      c.textController.text = 'an';
      await tester.pump();
      expect(c.suggestions.value, isNotEmpty);

      c.suggestionsEnabled = false;
      expect(c.suggestions.value, isEmpty);
    });

    testWidgets('selectSuggestion fills the field', (tester) async {
      final c = await controllerWith(store);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: c.textController,
              focusNode: c.focusNode,
            ),
          ),
        ),
      );
      c.focusNode.requestFocus();
      c.textController.text = 'an';
      await tester.pump();

      c.selectSuggestion(c.suggestions.value.single);
      expect(c.email, 'anna@example.com');
    });

    test('rememberCurrentEmail persists and refreshes', () async {
      final c = await controllerWith(store);
      addTearDown(c.dispose);
      c.setEmail(' new@example.com ');
      await c.rememberCurrentEmail();
      final emails = (await store.loadEntries()).map((e) => e.email);
      expect(emails, contains('new@example.com'));
    });

    test('does not dispose controllers it does not own', () {
      final text = TextEditingController();
      final focus = FocusNode();
      final c = EmailFieldController(
        store: store,
        textController: text,
        focusNode: focus,
      );
      c.dispose();
      // Would throw if disposed:
      text.text = 'still usable';
      focus.canRequestFocus = true;
      text.dispose();
      focus.dispose();
    });
  });

  group('RememberedEmailField', () {
    testWidgets('renders suggestions and selecting one fills the field', (
      tester,
    ) async {
      final c = await controllerWith(store);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RememberedEmailField(controller: c))),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'an');
      await tester.pump();

      expect(find.text('anna@example.com'), findsOneWidget);
      await tester.tap(find.text('anna@example.com'));
      await tester.pump();
      expect(c.email, 'anna@example.com');
    });

    testWidgets('email formatter lower-cases and strips spaces', (
      tester,
    ) async {
      final c = await controllerWith(store);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RememberedEmailField(controller: c))),
      );
      await tester.enterText(find.byType(TextFormField), 'A B@X.CO');
      expect(c.email, 'ab@x.co');
    });

    testWidgets('message, action and padding options apply', (tester) async {
      final c = await controllerWith(store);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RememberedEmailField(
              controller: c,
              invalidEmailMessage: 'Nope, that is not an email',
              textInputAction: TextInputAction.done,
              suggestionPadding: const EdgeInsets.only(top: 3),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'an');
      await tester.pump();

      expect(find.text('Nope, that is not an email'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textInputAction, TextInputAction.done);
      final view = tester.widget<EmailSuggestionsView>(
        find.byType(EmailSuggestionsView),
      );
      expect(view.padding, const EdgeInsets.only(top: 3));
    });

    testWidgets('fieldBuilder and suggestionBuilder replace the UI', (
      tester,
    ) async {
      final c = await controllerWith(store);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RememberedEmailField(
              controller: c,
              fieldBuilder:
                  (context, controller, focus) =>
                      TextField(controller: controller, focusNode: focus),
              suggestionBuilder:
                  (context, s, onTap) => TextButton(
                    onPressed: onTap,
                    child: Text('pick ${s.label}'),
                  ),
            ),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'an');
      await tester.pump();
      expect(find.text('pick anna@example.com'), findsOneWidget);
    });
  });

  test('EmailInputFormatter', () {
    const f = EmailInputFormatter();
    final out = f.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: 'A b@X.co',
        selection: TextSelection.collapsed(offset: 8),
      ),
    );
    expect(out.text, 'ab@x.co');
    expect(out.selection.baseOffset, 7);
  });

  test('EmailValidator', () {
    expect(EmailValidator.isValid('a@b.co'), isTrue);
    for (final bad in ['', 'a', 'a@', '@b.co', 'a@b', 'a b@c.com', null]) {
      expect(EmailValidator.isValid(bad), isFalse, reason: '$bad');
    }
    expect(EmailValidator.validate('x'), isNotNull);
    expect(EmailValidator.validate('x@y.zz'), isNull);
  });
}
