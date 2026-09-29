import 'package:craft_kit_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openSwipeTab(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const CraftKitExample());
  await tester.tap(find.text('Swipe'));
  await tester.pumpAndSettle();
}

/// Settles springs without waiting on `pumpAndSettle`'s idle detection alone.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 300 && tester.binding.hasScheduledFrame; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('each direction does its own thing when dragged', (tester) async {
    await openSwipeTab(tester);

    // Left: dismissed.
    await tester.drag(find.text('Aurora'), const Offset(-260, 0));
    await settle(tester);
    expect(find.textContaining('Aurora · nope'), findsOneWidget);
    expect(find.text('Aurora'), findsNothing);

    // Right: consumed by the like button, which counts it on arrival.
    await tester.drag(find.text('Bolt'), const Offset(260, 0));
    await settle(tester);
    expect(find.textContaining('Bolt · like'), findsOneWidget);
    expect(find.text('Bolt'), findsNothing);
    expect(find.byType(Badge), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // the like count

    // Up: runs a task and the card stays.
    await tester.drag(find.text('Coral'), const Offset(0, -260));
    await settle(tester);
    expect(find.textContaining('Coral · super'), findsOneWidget);
    expect(find.text('Coral'), findsOneWidget); // sprang back
    expect(find.textContaining('1 super'), findsOneWidget);

    // Down: sent to the end of the deck, so it is not the top card any more.
    await tester.drag(find.text('Coral'), const Offset(0, 260));
    await settle(tester);
    expect(find.textContaining('Coral · skip'), findsOneWidget);
    expect(find.text('Dune'), findsWidgets);
  });

  testWidgets('the buttons do the same through the controller', (tester) async {
    await openSwipeTab(tester);
    await tester.tap(find.byTooltip('Like'));
    await settle(tester);
    expect(find.textContaining('Aurora · like'), findsOneWidget);

    await tester.tap(find.byTooltip('Undo'));
    await settle(tester);
    expect(find.text('Aurora'), findsOneWidget); // back on top
  });

  testWidgets('cards are not rebuilt while one is being dragged', (
    tester,
  ) async {
    await openSwipeTab(tester);
    String builds() => RegExp(r'card builds: (\d+)')
        .firstMatch(
          tester.widget<Text>(find.textContaining('card builds')).data!,
        )!
        .group(1)!;

    final before = builds();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Aurora')),
    );
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(6, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    // The counter refreshes with the drag, so this is read mid-drag...
    expect(builds(), before);
    // ...and again after releasing back to rest and settling.
    await gesture.moveBy(const Offset(-120, 0));
    await gesture.up();
    await settle(tester);
    expect(builds(), before);
  });

  testWidgets('physics presets and the fan layout switch without trouble', (
    tester,
  ) async {
    await openSwipeTab(tester);
    for (final preset in <String>['snappy', 'bouncy', 'smooth']) {
      await tester.tap(find.text(preset));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Aurora'), const Offset(-240, 0));
      await settle(tester);
      await tester.tap(find.byTooltip('Undo'));
      await settle(tester);
    }
    await tester.tap(find.text('fan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Aurora'), findsOneWidget);
  });

  testWidgets('the deck can run out and start over', (tester) async {
    await openSwipeTab(tester);
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byTooltip('Nope'));
      await settle(tester);
    }
    expect(find.text('No more cards'), findsOneWidget);
    await tester.tap(find.text('Start over'));
    await settle(tester);
    expect(find.text('Aurora'), findsOneWidget);
  });

  testWidgets('switching tabs keeps the deck and never throws', (tester) async {
    await openSwipeTab(tester);
    await tester.drag(find.text('Aurora'), const Offset(-260, 0));
    await settle(tester);

    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OTP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Swipe'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aurora · nope'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
