import 'dart:math' as math;

import 'package:craft_kit/craft_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

void main() {
  group('rewind', () {
    Future<SwipeCardController> swipedFour(
      WidgetTester tester, {
      List<SwipeEvent<String>>? undone,
    }) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: const ['a', 'b', 'c', 'd', 'e'],
          controller: controller,
          onUndo: undone?.add,
        ),
      );
      for (var i = 0; i < 4; i++) {
        controller.swipe(SwipeDirection.right);
        await settle(tester);
      }
      return controller;
    }

    testWidgets('brings every swiped card back and restores the order', (
      tester,
    ) async {
      final undone = <SwipeEvent<String>>[];
      final controller = await swipedFour(tester, undone: undone);
      expect(controller.remaining.value, 1);
      final rest = centerOf(tester, 'e');

      controller.rewind();
      await settle(tester);

      expect(controller.remaining.value, 5);
      expect(controller.undoAvailable.value, isFalse);
      // Most recent first, so the deck ends up as it started.
      expect(undone.map((e) => e.item), ['d', 'c', 'b', 'a']);
      // a is on top again, at rest; the others sit behind it in order.
      expect(centerOf(tester, 'a'), rest);
      expect(centerOf(tester, 'b').dy, greaterThan(centerOf(tester, 'a').dy));
      expect(centerOf(tester, 'c').dy, greaterThan(centerOf(tester, 'b').dy));
    });

    testWidgets('the cards arrive one after another, not all at once', (
      tester,
    ) async {
      final controller = await swipedFour(tester);
      controller.rewind(stagger: const Duration(milliseconds: 120));
      await tester.pump(); // schedules
      await tester.pump(const Duration(milliseconds: 16)); // d starts

      var frames = 0;
      final appeared = <String, int>{};
      while (tester.binding.hasScheduledFrame && frames < 200) {
        for (final k in ['d', 'c', 'b', 'a']) {
          if (isBuilt(k)) appeared.putIfAbsent(k, () => frames);
        }
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      expect(appeared.keys.toList(), ['d', 'c', 'b', 'a']);
      // Each waits its turn: about 120 ms (7-8 frames) apart.
      expect(appeared['c']! - appeared['d']!, inInclusiveRange(5, 10));
      expect(appeared['a']! - appeared['b']!, inInclusiveRange(5, 10));
    });

    testWidgets('a returning card never jumps when the next one arrives', (
      tester,
    ) async {
      final controller = await swipedFour(tester);
      controller.rewind(stagger: const Duration(milliseconds: 100));
      await tester.pump();
      var previous = Offset.zero;
      var have = false;
      var worst = 0.0;
      for (var i = 0; i < 120 && tester.binding.hasScheduledFrame; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (!isBuilt('d')) continue;
        final now = centerOf(tester, 'd');
        if (have) worst = math.max(worst, (now - previous).distance);
        previous = now;
        have = true;
      }
      expect(have, isTrue);
      // A teleport into its slot would be a jump of 200+ px in one frame.
      expect(worst, lessThan(90));
    });

    testWidgets('two undos in the same frame both land, in order', (
      tester,
    ) async {
      final undone = <SwipeEvent<String>>[];
      final controller = await swipedFour(tester, undone: undone);
      controller.undo();
      controller.undo();
      await settle(tester);
      expect(undone.map((e) => e.item), ['d', 'c']);
      expect(controller.remaining.value, 3);
      final top = centerOf(tester, 'c');
      expect(top.dy, lessThan(centerOf(tester, 'd').dy)); // c above d
    });

    testWidgets('a card mid-return is handed over smoothly to the next undo', (
      tester,
    ) async {
      final controller = await swipedFour(tester);
      controller.undo(); // d starts coming back
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final before = tester.getBottomRight(find.byKey(cardKey('d')));
      controller.undo(); // c now goes on top of it
      await tester.pump(); // the frame the hand-over happens in
      final after = tester.getBottomRight(find.byKey(cardKey('d')));
      expect((after - before).distance, lessThan(2));
      await settle(tester);
    });

    testWidgets('count limits how many come back', (tester) async {
      final undone = <SwipeEvent<String>>[];
      final controller = await swipedFour(tester, undone: undone);
      controller.rewind(count: 2);
      await settle(tester);
      expect(undone.map((e) => e.item), ['d', 'c']);
      expect(controller.remaining.value, 3);
      expect(controller.undoAvailable.value, isTrue); // a and b remain
    });

    testWidgets('touching the top card stops it', (tester) async {
      final undone = <SwipeEvent<String>>[];
      final controller = await swipedFour(tester, undone: undone);
      controller.rewind(stagger: const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // d is on its way in, over the stack, well before the next one is due.
      await tester.pump(const Duration(milliseconds: 220));
      expect(undone.map((e) => e.item), ['d']);

      final gesture = await tester.startGesture(centerOf(tester, 'd'));
      await gesture.up();
      await settle(tester);
      // Touching the card ended the rewind: c, b and a stayed swiped.
      expect(undone.map((e) => e.item), ['d']);
      expect(controller.remaining.value, 2);
    });

    testWidgets('does nothing with nothing to bring back', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      controller.rewind();
      await settle(tester);
      expect(controller.remaining.value, 5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with reduced motion it finishes at once', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, reduceMotion: true),
      );
      for (var i = 0; i < 3; i++) {
        controller.swipe(SwipeDirection.left);
        await settle(tester);
      }
      controller.rewind();
      final frames = await settle(tester);
      expect(frames, lessThanOrEqualTo(10));
      expect(controller.remaining.value, 5);
    });

    testWidgets('a card is not lost if the deck changes during a rewind', (
      tester,
    ) async {
      final controller = await swipedFour(tester);
      controller.rewind(stagger: const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      controller.reset(); // in the middle
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(controller.remaining.value, 5);
    });
  });

  group('the undo behavior (drag down brings the previous card back)', () {
    final behaviors = <SwipeDirection, SwipeBehavior<String>>{
      SwipeDirection.left: SwipeBehavior<String>.dismiss(),
      SwipeDirection.right: SwipeBehavior<String>.dismiss(),
      SwipeDirection.down: SwipeBehavior<String>.undo(),
    };

    testWidgets('the previous card returns and the current one stays', (
      tester,
    ) async {
      final events = <SwipeEvent<String>>[];
      final undone = <SwipeEvent<String>>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: const ['a', 'b', 'c', 'd'],
          controller: controller,
          behaviors: behaviors,
          onSwipe: events.add,
          onUndo: undone.add,
        ),
      );
      controller.swipe(SwipeDirection.right); // a
      await settle(tester);
      controller.swipe(SwipeDirection.right); // b
      await settle(tester);
      expect(controller.remaining.value, 2); // c, d
      final rest = centerOf(tester, 'c');

      await tester.drag(find.text('c'), const Offset(0, 260));
      await tester.pump();
      expect(events.last.outcome, SwipeOutcome.undo);
      expect(events.last.direction, SwipeDirection.down);
      await settle(tester);

      // b is back on top; c did not leave, it sits behind b.
      expect(controller.remaining.value, 3);
      expect(centerOf(tester, 'b'), rest);
      expect(isBuilt('c'), isTrue);
      expect(centerOf(tester, 'c').dy, greaterThan(centerOf(tester, 'b').dy));
      expect(undone.map((e) => e.item), ['b']);
    });

    testWidgets('the card that was dragged springs back, it does not vanish', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: const ['a', 'b', 'c'],
          controller: controller,
          behaviors: behaviors,
        ),
      );
      controller.swipe(SwipeDirection.right);
      await settle(tester);

      final gesture = await tester.startGesture(centerOf(tester, 'b'));
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();
      final dragged = centerOf(tester, 'b').dy;
      await gesture.up();
      // It never disappears, and never jumps, while a comes in.
      var previous = dragged;
      var worst = 0.0;
      for (var i = 0; i < 60 && tester.binding.hasScheduledFrame; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        expect(isBuilt('b'), isTrue);
        final y = centerOf(tester, 'b').dy;
        worst = math.max(worst, (y - previous).abs());
        previous = y;
      }
      expect(worst, lessThan(40));
    });

    testWidgets('with nothing to bring back it just springs back', (
      tester,
    ) async {
      final events = <SwipeEvent<String>>[];
      final undone = <SwipeEvent<String>>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: const ['a', 'b'],
          controller: controller,
          behaviors: behaviors,
          onSwipe: events.add,
          onUndo: undone.add,
        ),
      );
      final rest = centerOf(tester, 'a');
      await tester.drag(find.text('a'), const Offset(0, 260));
      await settle(tester);
      expect(centerOf(tester, 'a'), rest);
      expect(undone, isEmpty);
      expect(controller.remaining.value, 2);
      expect(events.single.outcome, SwipeOutcome.undo); // still reported
    });

    testWidgets('a button can trigger it too, and it can repeat', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: const ['a', 'b', 'c', 'd'],
          controller: controller,
          behaviors: behaviors,
        ),
      );
      for (var i = 0; i < 3; i++) {
        controller.swipe(SwipeDirection.right);
        await settle(tester);
      }
      expect(controller.remaining.value, 1);
      controller.swipe(SwipeDirection.down);
      await settle(tester);
      expect(controller.remaining.value, 2);
      controller.swipe(SwipeDirection.down);
      await settle(tester);
      expect(controller.remaining.value, 3);
    });

    testWidgets('a guard can refuse it', (tester) async {
      final undone = <SwipeEvent<String>>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: const ['a', 'b', 'c'],
          controller: controller,
          onUndo: undone.add,
          behaviors: {
            SwipeDirection.right: SwipeBehavior<String>.dismiss(),
            SwipeDirection.down: SwipeBehavior<String>.undo(
              guard: (item) => false,
            ),
          },
        ),
      );
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      await tester.drag(find.text('b'), const Offset(0, 260));
      await settle(tester);
      expect(undone, isEmpty);
      expect(controller.remaining.value, 2);
    });
  });
}
