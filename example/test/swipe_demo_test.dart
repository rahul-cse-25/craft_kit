import 'package:craft_kit/craft_kit.dart';
import 'package:craft_kit_example/main.dart';
import 'package:craft_kit_example/swipe_lab.dart';
import 'package:craft_kit_example/swipe_lab_settings.dart';
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
Future<int> settle(WidgetTester tester) async {
  var frames = 0;
  await tester.pump();
  while (tester.binding.hasScheduledFrame && frames < 300) {
    await tester.pump(const Duration(milliseconds: 16));
    frames++;
  }
  return frames;
}

Future<void> openPanel(WidgetTester tester, {bool expand = false}) async {
  await tester.tap(find.byTooltip('Control center'));
  await tester.pumpAndSettle();
  if (expand) {
    await tester.drag(find.text('Control center'), const Offset(0, -700));
    await tester.pumpAndSettle();
  }
}

Future<void> closePanel(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Close'));
  await tester.pumpAndSettle();
}

Finder get panelScrollable => find
    .descendant(
      of: find.byType(SwipeControlCenter),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 160, scrollable: panelScrollable);
  // Let the sheet finish snapping before the next gesture.
  await tester.pumpAndSettle();
}

/// Collapsed sections do not build their children, so open one first.
Future<void> expandSection(WidgetTester tester, String title) async {
  final header = find.text(title);
  await reveal(tester, header);
  await tester.tap(header);
  await tester.pumpAndSettle();
}

Future<void> chooseAction(
  WidgetTester tester,
  SwipeDirection direction,
  DirectionAction action,
) async {
  final dropdown = find.byKey(ValueKey<String>('action-${direction.name}'));
  await reveal(tester, dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(DropdownMenuItem<DirectionAction>, action.label).last,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the demo', () {
    testWidgets('each direction does its own thing when dragged', (
      tester,
    ) async {
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
      expect(find.byType(Badge), findsWidgets);
      expect(find.text('1'), findsWidgets); // the like count

      // Up: runs a task and the card stays.
      await tester.drag(find.text('Coral'), const Offset(0, -260));
      await settle(tester);
      expect(find.textContaining('Coral · super'), findsOneWidget);
      expect(find.text('Coral'), findsOneWidget); // sprang back
      expect(find.textContaining('1 super'), findsOneWidget);

      // Down: brings the previous card back. The last one to leave was Bolt
      // (consumed into the like button), so it pours back out on top of Coral.
      await tester.drag(find.text('Coral'), const Offset(0, 260));
      await settle(tester);
      expect(find.textContaining('undo Bolt'), findsOneWidget);
      expect(find.text('Bolt'), findsOneWidget); // it is back
      expect(find.text('Coral'), findsOneWidget); // and Coral stayed
    });

    testWidgets('the buttons do the same through the controller', (
      tester,
    ) async {
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

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Aurora')),
      );
      // The first movement refreshes the counter (it is drawn from live
      // progress), so this is the true count going into the drag.
      await gesture.moveBy(const Offset(6, 0));
      await tester.pump();
      final before = builds();
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(6, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      // Nothing was rebuilt by 20 more movements...
      expect(builds(), before);
      // ...and again after releasing back to rest and settling.
      await gesture.moveBy(const Offset(-120, 0));
      await gesture.up();
      await settle(tester);
      expect(builds(), before);
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

    testWidgets('switching tabs keeps the deck and never throws', (
      tester,
    ) async {
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
  });

  group('the control center', () {
    testWidgets('opens from the top-right button, only on the swipe tab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const CraftKitExample());
      expect(find.byTooltip('Control center'), findsNothing); // email tab

      await tester.tap(find.text('Swipe'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Control center'), findsOneWidget);
      expect(find.text('Control center'), findsNothing);

      await openPanel(tester, expand: true);
      expect(find.text('Control center'), findsOneWidget);
      expect(find.text('Live readout'), findsOneWidget);
      // The list is lazy: later sections are built as they scroll into view.
      for (final title in <String>[
        'Directions: what each one does',
        'Physics: how it feels',
        'Springs: one per movement',
        'Layout: the cards behind',
        'Input, feedback and accessibility',
        'Deck and feeds',
        'Event log',
      ]) {
        await reveal(tester, find.text(title));
        expect(find.text(title), findsOneWidget);
      }

      await closePanel(tester);
      expect(find.text('Control center'), findsNothing);
    });

    testWidgets('changing a direction to dismiss takes effect at once', (
      tester,
    ) async {
      await openSwipeTab(tester);
      await openPanel(tester, expand: true);
      await chooseAction(tester, SwipeDirection.right, DirectionAction.dismiss);
      await closePanel(tester);

      await tester.drag(find.text('Aurora'), const Offset(260, 0));
      await settle(tester);
      expect(find.textContaining('Aurora · like'), findsOneWidget);
      // Dismissed, not consumed: it still counts as landed, so the badge is
      // on the like button either way, but the card flew off the screen.
      expect(find.text('Aurora'), findsNothing);
    });

    testWidgets('turning a direction off blocks it and disables its button', (
      tester,
    ) async {
      await openSwipeTab(tester);
      await openPanel(tester, expand: true);
      await chooseAction(tester, SwipeDirection.left, DirectionAction.off);
      await closePanel(tester);

      final nope = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.close),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(nope.onPressed, isNull);

      await tester.drag(find.text('Aurora'), const Offset(-260, 0));
      await settle(tester);
      expect(find.text('Aurora'), findsOneWidget); // resisted and came back
      expect(find.textContaining('nope'), findsNothing);
    });

    testWidgets('a guard makes a direction refuse a card', (tester) async {
      await openSwipeTab(tester);
      await openPanel(tester, expand: true);
      final chip = find.byKey(const ValueKey<String>('refuse-left'));
      await reveal(tester, chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await closePanel(tester);

      await tester.drag(find.text('Aurora'), const Offset(-260, 0));
      await settle(tester); // Aurora is fine
      expect(find.textContaining('Aurora · nope'), findsOneWidget);
      await tester.drag(find.text('Bolt'), const Offset(-260, 0));
      await settle(tester);
      // Coral is now on top: left refuses it.
      await tester.drag(find.text('Coral'), const Offset(-260, 0));
      await settle(tester);
      expect(find.text('Coral'), findsOneWidget);
    });

    testWidgets('the live readout follows the drag', (tester) async {
      await openSwipeTab(tester);
      await openPanel(tester);

      final gesture = await tester.startGesture(const Offset(200, 150));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      // Order: left, right, up, down.
      expect(bars[1].value, greaterThan(0.3));
      expect(bars[0].value, 0);
      await gesture.up();
      await settle(tester);
    });

    testWidgets('the event log records what happened', (tester) async {
      await openSwipeTab(tester);
      await tester.tap(find.byTooltip('Nope'));
      await settle(tester);

      await openPanel(tester, expand: true);
      final title = find.text('Event log');
      await reveal(tester, title);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('swipe  Aurora left dismiss (button)'),
        findsOneWidget,
      );
      expect(find.textContaining('landed Aurora'), findsOneWidget);
    });

    testWidgets('a physics preset applies to the next swipe', (tester) async {
      await openSwipeTab(tester);
      await openPanel(tester, expand: true);
      await expandSection(tester, 'Physics: how it feels');
      final snappy = find.text('snappy');
      await reveal(tester, snappy);
      await tester.tap(snappy);
      await tester.pumpAndSettle();
      await closePanel(tester);

      await tester.drag(find.text('Aurora'), const Offset(-260, 0));
      await settle(tester);
      expect(find.textContaining('Aurora · nope'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduce motion makes a swipe finish almost at once', (
      tester,
    ) async {
      await openSwipeTab(tester);
      await openPanel(tester, expand: true);
      await expandSection(tester, 'Input, feedback and accessibility');
      final toggle = find.text('Reduce motion');
      await reveal(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await closePanel(tester);

      await tester.tap(find.byTooltip('Nope'));
      // The card is gone within a couple of frames. (Counting every frame
      // until idle would also count the button's ink splash.)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Aurora'), findsNothing);
    });

    testWidgets('the infinite feed loads more cards when the deck runs low', (
      tester,
    ) async {
      await openSwipeTab(tester);
      await openPanel(tester, expand: true);
      await expandSection(tester, 'Deck and feeds');
      final feed = find.text('Infinite feed');
      await reveal(tester, feed);
      await tester.tap(feed);
      await tester.pumpAndSettle();
      await closePanel(tester);

      // 8 cards, load more at 3 left: after 5 swipes it tops up by 5.
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('Nope'));
        await settle(tester);
      }
      expect(find.textContaining('8 left'), findsOneWidget);
    });
  });

  group('rewind, undo and the genie in the demo', () {
    testWidgets('the rewind button brings every card back, in order', (
      tester,
    ) async {
      await openSwipeTab(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Nope'));
        await settle(tester);
      }
      expect(find.text('Aurora'), findsNothing);
      expect(find.text('Dune'), findsWidgets);

      await tester.tap(find.byTooltip('Rewind all'));
      await settle(tester);

      expect(find.text('Aurora'), findsOneWidget);
      expect(find.text('Bolt'), findsOneWidget);
      expect(find.text('Coral'), findsOneWidget);
      // With nothing left to undo the button is off.
      final rewind = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.fast_rewind),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(rewind.onPressed, isNull);
    });

    testWidgets('dragging down with nothing to bring back just springs back', (
      tester,
    ) async {
      await openSwipeTab(tester);
      await tester.drag(find.text('Aurora'), const Offset(0, 260));
      await settle(tester);
      expect(find.text('Aurora'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Down can be switched between undo and send to back', (
      tester,
    ) async {
      await openSwipeTab(tester);
      await openPanel(tester, expand: true);
      await chooseAction(
        tester,
        SwipeDirection.down,
        DirectionAction.sendToBack,
      );
      await closePanel(tester);

      // Sent to the back: the button is now "Skip" and the card leaves.
      expect(find.byTooltip('Skip'), findsOneWidget);
      await tester.drag(find.text('Aurora'), const Offset(0, 260));
      await settle(tester);
      expect(find.textContaining('Aurora · skip'), findsOneWidget);
    });

    testWidgets('the undo action is offered for every direction', (
      tester,
    ) async {
      await openSwipeTab(tester);
      await openPanel(tester, expand: true);
      // Make Up bring the previous card back instead.
      await chooseAction(tester, SwipeDirection.up, DirectionAction.undo);
      await closePanel(tester);

      await tester.tap(find.byTooltip('Nope'));
      await settle(tester);
      await tester.drag(find.text('Bolt'), const Offset(0, -260));
      await settle(tester);
      expect(find.text('Aurora'), findsOneWidget); // it came back
    });

    testWidgets('the genie can be switched off in the control center', (
      tester,
    ) async {
      await openSwipeTab(tester);
      await openPanel(tester, expand: true);
      final effect = find.byKey(const ValueKey<String>('consume-effect'));
      await reveal(tester, effect);
      await tester.tap(
        find.descendant(of: effect, matching: find.text('shrink')),
      );
      await tester.pumpAndSettle();
      await closePanel(tester);

      await tester.drag(find.text('Aurora'), const Offset(260, 0));
      await settle(tester);
      expect(find.textContaining('Aurora · like'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a genie swipe and its undo work from the buttons', (
      tester,
    ) async {
      await openSwipeTab(tester); // genie is the default for Like
      await tester.tap(find.byTooltip('Like'));
      await settle(tester);
      expect(find.text('Aurora'), findsNothing);

      await tester.tap(find.byTooltip('Undo'));
      await settle(tester);
      expect(find.text('Aurora'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SwipeLabSettings', () {
    test('defaults match the smooth preset and the demo behaviors', () {
      final s = SwipeLabSettings();
      expect(s.preset, 'smooth');
      expect(s.actions[SwipeDirection.right], DirectionAction.consume);
      expect(s.physics.commitThreshold, SwipePhysics.smooth.commitThreshold);
      expect(s.physics.settle, SwipePhysics.smooth.settle);
      expect(s.layout.visibleCards, 3);
      expect(s.haptics.thresholdCrossed, SwipeHapticType.selectionClick);
    });

    test(
      'Down brings the previous card back by default, and the genie is on',
      () {
        final s = SwipeLabSettings();
        expect(s.actions[SwipeDirection.down], DirectionAction.undo);
        expect(DirectionAction.undo.label, contains('bring back'));
        expect(s.consumeEffect, SwipeConsumeEffect.genie);
        expect(s.genieLag, 0.45);
        expect(s.rewindStagger, 90);

        s
          ..change(() {
            s.consumeEffect = SwipeConsumeEffect.shrink;
            s.rewindStagger = 10;
            s.actions[SwipeDirection.down] = DirectionAction.off;
          })
          ..resetAll();
        expect(s.consumeEffect, SwipeConsumeEffect.genie);
        expect(s.rewindStagger, 90);
        expect(s.actions[SwipeDirection.down], DirectionAction.undo);
      },
    );

    test('loading a preset replaces every spring', () {
      final s = SwipeLabSettings()..loadPreset('bouncy');
      expect(s.preset, 'bouncy');
      expect(s.physics.settle, SwipePhysics.bouncy.settle);
      expect(s.physics.promote, SwipePhysics.bouncy.promote);
    });

    test('editing physics makes the preset custom, and feeds the physics', () {
      final s = SwipeLabSettings();
      s.changePhysics(() => s.commitThreshold = 0.55);
      expect(s.preset, 'custom');
      expect(s.physics.commitThreshold, 0.55);
    });

    test('layout and haptics follow their settings', () {
      final s = SwipeLabSettings();
      s.change(() {
        s.visibleCards = 5;
        s.tilt = 0.08;
        s.hapticThreshold = false;
      });
      expect(s.layout.visibleCards, 5);
      expect(s.layout.tilt, 0.08);
      expect(s.haptics.thresholdCrossed, isNull);
      expect(s.haptics.commit, SwipeHapticType.lightImpact);
    });

    test('reset all restores everything and asks for a new deck', () {
      final s = SwipeLabSettings();
      final version = s.deckVersion;
      s
        ..loadPreset('snappy')
        ..change(() {
          s.actions[SwipeDirection.left] = DirectionAction.off;
          s.visibleCards = 1;
          s.infinite = true;
        })
        ..resetAll();
      expect(s.preset, 'smooth');
      expect(s.actions[SwipeDirection.left], DirectionAction.dismiss);
      expect(s.visibleCards, 3);
      expect(s.infinite, isFalse);
      expect(s.deckVersion, greaterThan(version));
    });

    test('the event log keeps only the newest lines', () {
      final s = SwipeLabSettings();
      for (var i = 0; i < 60; i++) {
        s.log('event $i');
      }
      expect(s.events, hasLength(40));
      expect(s.events.first, 'event 59');
    });

    test('a generated deck has unique cards and grows past the base set', () {
      final deck = makeDeck(20);
      expect(deck, hasLength(20));
      expect(deck.map((p) => p.name).toSet(), hasLength(20));
      expect(identical(deck[0], makeDeck(20)[0]), isFalse);
    });
  });
}
