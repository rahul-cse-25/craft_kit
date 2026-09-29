import 'package:craft_kit/craft_kit.dart';
import 'package:craft_kit/src/swipe_card/swipe_card_stack.dart'
    show debugLiveGenieImages;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

/// Right consumes into the target with the genie; left just dismisses.
Map<SwipeDirection, SwipeBehavior<String>> genieBehaviors({
  void Function(String)? onArrive,
  SwipeConsumeEffect effect = SwipeConsumeEffect.genie,
}) => <SwipeDirection, SwipeBehavior<String>>{
  SwipeDirection.left: SwipeBehavior<String>.dismiss(),
  SwipeDirection.right: SwipeBehavior<String>.consume(
    target: SwipeTarget(key: targetKey, effect: effect),
    onArrive: onArrive,
  ),
};

/// The genie drawings currently in the tree.
Finder get geniePainters => find.byWidgetPredicate(
  (w) =>
      w is CustomPaint &&
      w.painter != null &&
      w.painter.runtimeType.toString() == '_GeniePainter',
);

void main() {
  setUp(() => debugLiveGenieImages = 0);

  group('the genie going in', () {
    testWidgets('the card is drawn as a warped picture, then arrives', (
      tester,
    ) async {
      final arrived = <String>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          controller: controller,
          behaviors: genieBehaviors(onArrive: arrived.add),
        ),
      );
      expect(geniePainters, findsNothing);

      controller.swipe(SwipeDirection.right);
      await tester.pump(); // commit
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 120));

      // Mid-way: the live card is replaced by its warped picture.
      expect(geniePainters, findsOneWidget);
      expect(isBuilt('a'), isFalse);
      expect(controller.consuming.value, isNotNull);
      expect(arrived, isEmpty);

      await settle(tester);
      expect(geniePainters, findsNothing);
      expect(arrived, ['a']);
      expect(isBuilt('a'), isFalse);
      expect(controller.consuming.value, isNull);
    });

    testWidgets('the next card is not held up, and rises as it leaves', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, behaviors: genieBehaviors()),
      );
      final before = tester.getBottomRight(find.byKey(cardKey('b')));
      controller.swipe(SwipeDirection.right);
      await tester.pump();
      final commit = tester.getBottomRight(find.byKey(cardKey('b')));
      expect((commit - before).distance, lessThan(0.5)); // no jump
      await settle(tester);
      // b is now the top card at rest.
      expect(isBuilt('b'), isTrue);
    });

    testWidgets('dragging by hand consumes with the genie too', (tester) async {
      final events = <SwipeEvent<String>>[];
      await tester.pumpWidget(
        swipeApp(behaviors: genieBehaviors(), onSwipe: events.add),
      );
      await dragWithVelocity(tester, 'a', const Offset(180, 30));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      expect(geniePainters, findsOneWidget);
      await settle(tester);
      expect(events.single.outcome, SwipeOutcome.consume);
    });

    testWidgets('effect shrink still uses the plain shrinking card', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          controller: controller,
          behaviors: genieBehaviors(effect: SwipeConsumeEffect.shrink),
        ),
      );
      controller.swipe(SwipeDirection.right);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      expect(geniePainters, findsNothing);
      expect(isBuilt('a'), isTrue); // the live card, shrinking
      await settle(tester);
    });

    testWidgets('a target that is not on screen falls back to leaving', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          controller: controller,
          behaviors: {
            SwipeDirection.right: SwipeBehavior<String>.consume(
              target: SwipeTarget(
                key: GlobalKey(),
                effect: SwipeConsumeEffect.genie,
              ),
            ),
          },
        ),
      );
      controller.swipe(SwipeDirection.right);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(geniePainters, findsNothing);
      await settle(tester);
      expect(debugLiveGenieImages, 0);
    });
  });

  group('the genie coming back out (undo)', () {
    testWidgets('the card pours back out of the button, then is live again', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, behaviors: genieBehaviors()),
      );
      final rest = centerOf(tester, 'a');
      controller.swipe(SwipeDirection.right);
      await settle(tester);

      controller.undo();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 120));
      // Pouring out: drawn as a picture, the live card is not shown yet.
      expect(geniePainters, findsOneWidget);
      expect(isBuilt('a'), isFalse);

      await settle(tester);
      expect(geniePainters, findsNothing);
      expect(isBuilt('a'), isTrue);
      expect(centerOf(tester, 'a'), rest);
      expect(opacityOf(tester, 'a'), 1);
      expect(controller.remaining.value, 5);
    });

    testWidgets('it can be undone while it is still pouring in', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, behaviors: genieBehaviors()),
      );
      controller.swipe(SwipeDirection.right);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 90));

      controller.undo();
      await settle(tester);
      expect(isBuilt('a'), isTrue);
      expect(geniePainters, findsNothing);
      expect(tester.takeException(), isNull);
      expect(debugLiveGenieImages, 0); // nothing left over
    });

    testWidgets('the top card cannot be grabbed or swiped while it pours out', (
      tester,
    ) async {
      final events = <SwipeEvent<String>>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          controller: controller,
          behaviors: genieBehaviors(),
          onSwipe: events.add,
        ),
      );
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      events.clear();

      controller.undo();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      controller.swipe(SwipeDirection.left); // ignored: not settled yet
      await tester.pump();
      expect(events, isEmpty);
      await settle(tester);
    });

    testWidgets('a rewind pours every consumed card back, in place', (
      tester,
    ) async {
      final undone = <SwipeEvent<String>>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          controller: controller,
          behaviors: genieBehaviors(),
          onUndo: undone.add,
        ),
      );
      for (var i = 0; i < 3; i++) {
        controller.swipe(SwipeDirection.right);
        await settle(tester);
      }
      controller.rewind(stagger: const Duration(milliseconds: 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 200));
      // Several are pouring back at once.
      expect(geniePainters.evaluate().length, greaterThan(1));

      await settle(tester);
      expect(geniePainters, findsNothing);
      expect(undone.map((e) => e.item), ['c', 'b', 'a']);
      expect(controller.remaining.value, 5);
      expect(tester.takeException(), isNull);
      // a is on top, at rest, with b and c behind it in their slots.
      expect(centerOf(tester, 'b').dy, greaterThan(centerOf(tester, 'a').dy));
    });

    testWidgets('a returning genie card follows its slot as others arrive', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, behaviors: genieBehaviors()),
      );
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      controller.swipe(SwipeDirection.right);
      await settle(tester);

      controller.undo(); // b pours out
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 80));
      controller.undo(); // a goes on top of it, while b is still pouring
      await settle(tester);

      expect(geniePainters, findsNothing);
      // b ended behind a, in the second slot.
      expect(centerOf(tester, 'a').dy, lessThan(centerOf(tester, 'b').dy));
      expect(controller.remaining.value, 5);
    });
  });

  group('pictures are never leaked', () {
    testWidgets('kept while they can be undone, freed after', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, behaviors: genieBehaviors()),
      );
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      // Two swipes are undoable, so two pictures are kept.
      expect(debugLiveGenieImages, 2);

      controller.undo();
      await settle(tester);
      // One came back and its picture is released.
      expect(debugLiveGenieImages, 1);

      controller.reset();
      await tester.pump();
      expect(debugLiveGenieImages, 0);
    });

    testWidgets('only the most recent few are kept', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: List<String>.generate(20, (i) => 'i$i'),
          controller: controller,
          behaviors: genieBehaviors(),
        ),
      );
      for (var i = 0; i < 12; i++) {
        controller.swipe(SwipeDirection.right);
        await settle(tester);
      }
      expect(debugLiveGenieImages, lessThanOrEqualTo(8));
      expect(debugLiveGenieImages, greaterThan(0));
    });

    testWidgets('history limit 0 keeps none', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          controller: controller,
          behaviors: genieBehaviors(),
          historyLimit: 0,
        ),
      );
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      expect(debugLiveGenieImages, 0);
    });

    testWidgets('disposing the stack frees everything, even mid-animation', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, behaviors: genieBehaviors()),
      );
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      controller.swipe(SwipeDirection.right);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 60)); // in flight
      controller.undo(); // and one pouring back out
      await tester.pump(const Duration(milliseconds: 40));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(debugLiveGenieImages, 0);
    });

    testWidgets('a long random session ends with nothing leaked', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: List<String>.generate(10, (i) => 'i$i'),
          controller: controller,
          behaviors: genieBehaviors(),
        ),
      );
      for (var i = 0; i < 60; i++) {
        switch (i % 5) {
          case 0:
          case 1:
            controller.swipe(SwipeDirection.right);
          case 2:
            controller.undo();
          case 3:
            controller.rewind(count: 2);
          default:
            if (i % 15 == 4) controller.reset();
        }
        await tester.pump(Duration(milliseconds: 20 + (i * 7) % 90));
        expect(tester.takeException(), isNull, reason: 'step $i');
      }
      await settle(tester);
      controller.reset();
      await tester.pump();
      expect(debugLiveGenieImages, 0);
      await tester.pumpWidget(const SizedBox());
      expect(debugLiveGenieImages, 0);
    });
  });
}
