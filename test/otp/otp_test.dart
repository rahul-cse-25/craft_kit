import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OtpController.extractCode', () {
    final c = OtpController(length: 6);
    tearDownAll(c.dispose);

    test('strips separators', () {
      expect(c.extractCode('123 456'), '123456');
      expect(c.extractCode('12-34-56'), '123456');
    });

    test('finds a standalone code inside a message', () {
      expect(c.extractCode('Your code is 482913. Valid for 5 min'), '482913');
      expect(c.extractCode('Order 22 code 654321'), '654321');
    });

    test('truncates and drops letters', () {
      expect(c.extractCode('1234567890'), '123456');
      expect(c.extractCode('ab12cd'), '12');
    });

    test('alphanumeric keeps letters', () {
      final a = OtpController(length: 4, inputType: OtpInputType.alphanumeric);
      expect(a.extractCode('a1-B2'), 'a1B2');
      a.dispose();
    });
  });

  test('setValue and clear notify listeners', () {
    final c = OtpController(length: 4);
    var calls = 0;
    c.addListener(() => calls++);
    c.setValue('12 34');
    expect(c.value, '1234');
    expect(c.isComplete, isTrue);
    c.clear();
    expect(c.isEmpty, isTrue);
    expect(calls, 2);
    c.dispose();
  });

  testWidgets('pasteFromClipboard fills the code', (tester) async {
    final c = OtpController(length: 6);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, dynamic>{'text': 'G-731 905 is your code'}
          : null,
    );
    expect(await c.pasteFromClipboard(), isTrue);
    expect(c.value, '731905');
    c.dispose();
  });

  testWidgets('OtpField types, handles bulk input, fires onCompleted once', (
    tester,
  ) async {
    final c = OtpController(length: 4);
    final completed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: OtpField(
              controller: c,
              autofocus: true,
              onCompleted: completed.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '12');
    expect(c.value, '12');

    // Simulates a paste / autofill of a noisy string.
    await tester.enterText(find.byType(TextField), '12 34 99');
    expect(c.value, '1234');
    expect(completed, ['1234']);

    // Typing past the end is ignored.
    await tester.enterText(find.byType(TextField), '12345');
    expect(c.value, '1234');
    expect(completed, ['1234']);

    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
