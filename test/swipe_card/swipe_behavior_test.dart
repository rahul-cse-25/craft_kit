import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

void main() {
  group('dismiss', () {
    testWidgets('a drag past the threshold sends the card away', (
      tester,
    ) async {
      final events = <SwipeEvent<String>>[];
      final ended = <String>[];
      await tester.pumpWidget(
        swipeApp(onSwipe: events.add, onSwipeEnd: (e) => ended.add(e.item)),
      );

      await tester.drag(find.text('a'), const Offset(200, 0));
      await tester.pump();

      // The callback fires at commit, not after the animation.
      expect(events, hasLength(1));
      expect(events.single.item, 'a');
      expect(events.single.direction, SwipeDirection.right);
      expect(events.single.outcome, SwipeOutcome.dismiss);
      expect(events.single.programmatic, isFalse);
      expect(events.single.remaining, 4);
      expect(ended, isEmpty);

      await settle(tester);
      expect(ended, ['a']);
      expect(isBuilt('a'), isFalse);
      expect(isBuilt('b'), isTrue);
    });

    testWidgets('a short drag springs back and is not a swipe', (tester) async {
      final events = <SwipeEvent<String>>[];
      await tester.pumpWidget(swipeApp(onSwipe: events.add));
      final rest = centerOf(tester, 'a');

      await tester.drag(find.text('a'), const Offset(-30, 0));
      await settle(tester);

      expect(events, isEmpty);
      expect(centerOf(tester, 'a'), rest);
    });

    testWidgets('all four directions work when they have behaviors', (
      tester,
    ) async {
      final directions = <SwipeDirection>[];
      await tester.pumpWidget(
        swipeApp(
          items: const ['a', 'b', 'c', 'd'],
          behaviors: SwipeBehaviors.all<String>(),
          onSwipe: (e) => directions.add(e.direction),
        ),
      );
      await tester.drag(find.text('a'), const Offset(-200, 0));
      await settle(tester);
      await tester.drag(find.text('b'), const Offset(0, -250));
      await settle(tester);
      await tester.drag(find.text('c'), const Offset(0, 250));
      await settle(tester);
      await tester.drag(find.text('d'), const Offset(200, 0));
      await settle(tester);
      expect(directions, [
        SwipeDirection.left,
        SwipeDirection.up,
        SwipeDirection.down,
        SwipeDirection.right,
      ]);
    });

    testWidgets('onEnd fires once, after the last card, and empty shows', (
      tester,
    ) async {
      var ended = 0;
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: const ['a', 'b'],
          controller: controller,
          onEnd: () => ended++,
        ),
      );
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      expect(ended, 0);
      controller.swipe(SwipeDirection.left);
      await settle(tester);
      expect(ended, 1);
      expect(find.text('empty'), findsOneWidget);
      expect(controller.remaining.value, 0);
    });
  });

  group('per-direction behaviors', () {
    testWidgets('springBack runs the task and the card stays in the deck', (
      tester,
    ) async {
      final triggered = <String>[];
      final events = <SwipeEvent<String>>[];
      await tester.pumpWidget(
        swipeApp(
          behaviors: {
            SwipeDirection.right: SwipeBehavior<String>.dismiss(),
            SwipeDirection.up: SwipeBehavior<String>.springBack(
              onCommit: (e) => triggered.add(e.item),
            ),
          },
          onSwipe: events.add,
        ),
      );
      final rest = centerOf(tester, 'a');

      await tester.drag(find.text('a'), const Offset(0, -250));
      await tester.pump();
      expect(triggered, ['a']);
      expect(events.single.outcome, SwipeOutcome.springBack);
      expect(events.single.remaining, 5); // nothing left the deck

      await settle(tester);
      expect(centerOf(tester, 'a'), rest);
      expect(isBuilt('a'), isTrue);

      // It can be triggered again, on the same card.
      await tester.drag(find.text('a'), const Offset(0, -250));
      await settle(tester);
      expect(triggered, ['a', 'a']);
    });

    testWidgets('sendToBack puts the card at the end of the deck', (
      tester,
    ) async {
      final order = <String>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: const ['a', 'b', 'c'],
          controller: controller,
          behaviors: {SwipeDirection.down: SwipeBehavior<String>.sendToBack()},
          onSwipe: (e) => order.add(e.item),
        ),
      );
      for (var i = 0; i < 4; i++) {
        controller.swipe(SwipeDirection.down);
        await settle(tester);
      }
      expect(order, ['a', 'b', 'c', 'a']);
      expect(controller.remaining.value, 3);
      expect(find.byKey(cardKey('a')), findsOneWidget);
    });

    testWidgets('a guard refuses a swipe and the card springs back', (
      tester,
    ) async {
      final events = <SwipeEvent<String>>[];
      await tester.pumpWidget(
        swipeApp(
          behaviors: {
            SwipeDirection.right: SwipeBehavior<String>.dismiss(
              guard: (item) => item != 'a',
            ),
          },
          onSwipe: events.add,
        ),
      );
      final rest = centerOf(tester, 'a');
      await tester.drag(find.text('a'), const Offset(220, 0));
      await settle(tester);
      expect(events, isEmpty);
      expect(centerOf(tester, 'a'), rest);
    });

    testWidgets('a direction without a behavior resists and springs back', (
      tester,
    ) async {
      final events = <SwipeEvent<String>>[];
      await tester.pumpWidget(swipeApp(onSwipe: events.add));
      final rest = centerOf(tester, 'a');

      final gesture = await tester.startGesture(rest);
      await gesture.moveBy(const Offset(0, -300));
      await tester.pump();
      final stretched = rest.dy - centerOf(tester, 'a').dy;
      expect(stretched, greaterThan(5)); // it follows a little...
      expect(stretched, lessThan(36)); // ...but never past the limit
      await gesture.up();
      await settle(tester);
      expect(events, isEmpty);
      expect(centerOf(tester, 'a'), rest);
    });

    testWidgets('each direction can do something different', (tester) async {
      final outcomes = <SwipeOutcome>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: const ['a', 'b', 'c', 'd'],
          controller: controller,
          behaviors: {
            SwipeDirection.left: SwipeBehavior<String>.dismiss(),
            SwipeDirection.right: SwipeBehavior<String>.consume(
              target: SwipeTarget(key: targetKey),
            ),
            SwipeDirection.up: SwipeBehavior<String>.springBack(),
            SwipeDirection.down: SwipeBehavior<String>.sendToBack(),
          },
          onSwipe: (e) => outcomes.add(e.outcome),
        ),
      );
      for (final d in [
        SwipeDirection.left,
        SwipeDirection.right,
        SwipeDirection.up,
        SwipeDirection.down,
      ]) {
        controller.swipe(d);
        await settle(tester);
      }
      expect(outcomes, [
        SwipeOutcome.dismiss,
        SwipeOutcome.consume,
        SwipeOutcome.springBack,
        SwipeOutcome.sendToBack,
      ]);
    });
  });

  group('consume', () {
    testWidgets('the card travels into the target, shrinking', (tester) async {
      final arrived = <String>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          controller: controller,
          behaviors: {
            SwipeDirection.right: SwipeBehavior<String>.consume(
              target: SwipeTarget(key: targetKey),
              onArrive: arrived.add,
            ),
          },
        ),
      );
      final start = centerOf(tester, 'a');
      final target = tester.getCenter(find.byKey(targetKey));

      controller.swipe(SwipeDirection.right);
      await tester.pump(); // commit
      await tester.pump(const Duration(milliseconds: 16)); // first frame
      await tester.pump(const Duration(milliseconds: 160));

      // Mid-way: between start and target, and already smaller.
      final mid = centerOf(tester, 'a');
      expect((mid - target).distance, lessThan((start - target).distance));
      expect((mid - start).distance, greaterThan(20));
      final size = tester.getSize(find.byKey(cardKey('a')));
      final corner =
          tester.getBottomRight(find.byKey(cardKey('a'))) -
          tester.getTopLeft(find.byKey(cardKey('a')));
      expect(corner.dx, lessThan(size.width));
      expect(controller.consuming.value, isNotNull);
      expect(controller.consuming.value!.direction, SwipeDirection.right);
      expect(arrived, isEmpty);

      await settle(tester);
      expect(arrived, ['a']);
      expect(isBuilt('a'), isFalse);
      expect(controller.consuming.value, isNull);
    });

    testWidgets('ends exactly on the target', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          controller: controller,
          behaviors: {
            SwipeDirection.right: SwipeBehavior<String>.consume(
              target: SwipeTarget(key: targetKey),
            ),
          },
        ),
      );
      final target = tester.getCenter(find.byKey(targetKey));
      controller.swipe(SwipeDirection.right);
      await tester.pump();
      var last = centerOf(tester, 'a');
      // Follow the card to the end; just before it disappears it is at the
      // target.
      for (var i = 0; i < 200 && isBuilt('a'); i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (isBuilt('a')) last = centerOf(tester, 'a');
      }
      expect((last - target).distance, lessThan(12));
    });

    testWidgets('a target that is not on screen falls back to leaving', (
      tester,
    ) async {
      final events = <SwipeEvent<String>>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          controller: controller,
          behaviors: {
            SwipeDirection.right: SwipeBehavior<String>.consume(
              target: SwipeTarget(key: GlobalKey()), // never attached
            ),
          },
          onSwipe: events.add,
        ),
      );
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      expect(events.single.outcome, SwipeOutcome.dismiss);
      expect(isBuilt('a'), isFalse);
    });

    testWidgets('dragging by hand consumes too, with a curved path', (
      tester,
    ) async {
      final events = <SwipeEvent<String>>[];
      await tester.pumpWidget(
        swipeApp(
          behaviors: {
            SwipeDirection.left: SwipeBehavior<String>.consume(
              target: SwipeTarget(key: targetKey),
            ),
          },
          onSwipe: events.add,
        ),
      );
      await dragWithVelocity(tester, 'a', const Offset(-180, 40));
      await settle(tester);
      expect(events.single.direction, SwipeDirection.left);
      expect(events.single.outcome, SwipeOutcome.consume);
      expect(events.single.programmatic, isFalse);
    });
  });

  group('undo', () {
    testWidgets('brings a dismissed card back and restores the count', (
      tester,
    ) async {
      final undone = <SwipeEvent<String>>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, onUndo: undone.add),
      );
      final rest = centerOf(tester, 'a');
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      expect(controller.undoAvailable.value, isTrue);
      expect(controller.remaining.value, 4);

      controller.undo();
      await tester.pump();
      expect(undone.single.item, 'a');
      await settle(tester);

      expect(centerOf(tester, 'a'), rest);
      expect(controller.remaining.value, 5);
      expect(controller.undoAvailable.value, isFalse);
    });

    testWidgets('can undo while the card is still flying away', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      final rest = centerOf(tester, 'a');
      controller.swipe(SwipeDirection.right);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(isBuilt('a'), isTrue);

      controller.undo();
      await settle(tester);
      expect(centerOf(tester, 'a'), rest);
      expect(find.byKey(cardKey('a')), findsOneWidget);
    });

    testWidgets('a consumed card comes back from the target', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          controller: controller,
          behaviors: {
            SwipeDirection.right: SwipeBehavior<String>.consume(
              target: SwipeTarget(key: targetKey),
            ),
          },
        ),
      );
      final rest = centerOf(tester, 'a');
      final target = tester.getCenter(find.byKey(targetKey));
      controller.swipe(SwipeDirection.right);
      await settle(tester);

      controller.undo();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // It starts at the target, small and transparent...
      expect((centerOf(tester, 'a') - target).distance, lessThan(60));
      expect(opacityOf(tester, 'a'), lessThan(0.5));
      await settle(tester);
      // ...and ends at rest, fully visible.
      expect(centerOf(tester, 'a'), rest);
      expect(opacityOf(tester, 'a'), 1);
    });

    testWidgets('undoing a send-to-back removes the copy at the end', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: const ['a', 'b', 'c'],
          controller: controller,
          behaviors: {SwipeDirection.down: SwipeBehavior<String>.sendToBack()},
        ),
      );
      controller.swipe(SwipeDirection.down);
      await settle(tester);
      controller.undo();
      await settle(tester);
      expect(controller.remaining.value, 3);
      expect(find.byKey(cardKey('a')), findsOneWidget);
    });

    testWidgets('history is bounded by historyLimit', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, historyLimit: 2),
      );
      for (var i = 0; i < 4; i++) {
        controller.swipe(SwipeDirection.right);
        await settle(tester);
      }
      controller.undo();
      await settle(tester);
      controller.undo();
      await settle(tester);
      expect(controller.undoAvailable.value, isFalse);
      expect(controller.remaining.value, 3); // 5 - 4 + 2
    });

    testWidgets('reset starts the deck over', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      controller.swipe(SwipeDirection.left);
      await settle(tester);
      controller.reset();
      await tester.pump();
      expect(controller.remaining.value, 5);
      expect(controller.undoAvailable.value, isFalse);
      expect(isBuilt('a'), isTrue);
    });
  });

  group('items', () {
    testWidgets('an equal but new list does not reset the deck', (
      tester,
    ) async {
      await tester.pumpWidget(swipeApp(items: ['a', 'b', 'c']));
      await tester.drag(find.text('a'), const Offset(220, 0));
      await settle(tester);
      expect(isBuilt('a'), isFalse);

      await tester.pumpWidget(swipeApp(items: ['a', 'b', 'c'])); // new list
      await tester.pump();
      expect(isBuilt('a'), isFalse); // still swiped; not resurrected
      expect(isBuilt('b'), isTrue);
    });

    testWidgets('items that are appended join the end', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(items: ['a', 'b'], controller: controller),
      );
      await tester.pumpWidget(
        swipeApp(items: ['a', 'b', 'c', 'd'], controller: controller),
      );
      await tester.pump();
      await tester.pump();
      expect(controller.remaining.value, 4);
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      expect(isBuilt('c'), isTrue);
    });

    testWidgets('items that are removed disappear from the deck', (
      tester,
    ) async {
      await tester.pumpWidget(swipeApp(items: ['a', 'b', 'c']));
      await tester.pumpWidget(swipeApp(items: ['a', 'c']));
      await tester.pump();
      expect(isBuilt('b'), isFalse);
      expect(isBuilt('c'), isTrue);
    });

    testWidgets('onNeedMore fires once when the deck runs low', (tester) async {
      final asked = <int>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: ['a', 'b', 'c', 'd', 'e'],
          controller: controller,
          onNeedMore: asked.add,
        ),
      );
      controller.swipe(SwipeDirection.right); // 4 left
      await settle(tester);
      expect(asked, isEmpty);
      controller.swipe(SwipeDirection.right); // 3 left = threshold
      await settle(tester);
      expect(asked, [3]);
      controller.swipe(SwipeDirection.right); // 2 left: already asked
      await settle(tester);
      expect(asked, [3]);
    });

    testWidgets('onPreload is called once per upcoming item', (tester) async {
      final preloaded = <String>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: List<String>.generate(8, (i) => 'i$i'),
          controller: controller,
          onPreload: (context, item, depth) => preloaded.add(item),
        ),
      );
      await tester.pump();
      // 3 visible + 1 hidden + 2 preloaded.
      expect(preloaded, ['i0', 'i1', 'i2', 'i3', 'i4', 'i5']);
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      expect(preloaded.last, 'i6');
      expect(preloaded.toSet(), hasLength(preloaded.length)); // no repeats
    });
  });

  group('input', () {
    testWidgets('enabled: false ignores touch but not the controller', (
      tester,
    ) async {
      final events = <SwipeEvent<String>>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, enabled: false, onSwipe: events.add),
      );
      await tester.drag(find.text('a'), const Offset(220, 0));
      await settle(tester);
      expect(events, isEmpty);
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      expect(events, hasLength(1));
    });

    testWidgets('arrow keys swipe while the stack has focus', (tester) async {
      final events = <SwipeEvent<String>>[];
      await tester.pumpWidget(swipeApp(autofocus: true, onSwipe: events.add));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // no behavior
      await settle(tester);
      expect(events.map((e) => e.direction), [SwipeDirection.right]);
    });

    testWidgets('screen readers get a custom action per open direction', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(swipeApp());
      final actions = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.customSemanticsActions?.isNotEmpty ?? false),
      );
      expect(actions, findsOneWidget);
      final data = tester.getSemantics(actions).getSemanticsData();
      expect(data.customSemanticsActionIds, hasLength(2)); // left and right
      handle.dispose();
    });

    testWidgets('the overlay sees independent progress per direction', (
      tester,
    ) async {
      SwipeProgress? seen;
      await tester.pumpWidget(
        swipeApp(
          behaviors: SwipeBehaviors.all<String>(),
          overlayBuilder: (context, progress) {
            seen = progress;
            return const SizedBox.expand();
          },
        ),
      );
      final gesture = await tester.startGesture(centerOf(tester, 'a'));
      await gesture.moveBy(const Offset(40, 30));
      await tester.pump();
      expect(seen, isNotNull);
      expect(seen!.right, greaterThan(0));
      expect(seen!.down, greaterThan(0)); // both, so no flicker between them
      expect(seen!.left, 0);
      await gesture.up();
      await settle(tester);
    });

    testWidgets('the controller exposes live drag progress', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      final gesture = await tester.startGesture(centerOf(tester, 'a'));
      await gesture.moveBy(const Offset(45, 0));
      await tester.pump();
      expect(controller.progress.value.right, closeTo(0.5, 0.1));
      await gesture.up();
      await settle(tester);
      expect(controller.progress.value.isActive, isFalse);
    });
  });

  group('haptics', () {
    testWidgets('fires when the threshold is crossed and on commit', (
      tester,
    ) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(swipeApp(haptics: const SwipeHaptics()));

      final gesture = await tester.startGesture(centerOf(tester, 'a'));
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(10, 0)); // reaches 120 (> 90)
        await tester.pump();
      }
      expect(calls.where((c) => c.endsWith('selectionClick')), hasLength(1));

      // Pull back below the threshold, then across it again: one more tick.
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump();
      }
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      expect(calls.where((c) => c.endsWith('selectionClick')), hasLength(2));

      await gesture.up();
      await tester.pump();
      expect(calls.where((c) => c.endsWith('lightImpact')), hasLength(1));
      await settle(tester);
    });
  });

  group('reduced motion', () {
    testWidgets('a swipe completes in a couple of frames', (tester) async {
      final ended = <String>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          controller: controller,
          reduceMotion: true,
          onSwipeEnd: (e) => ended.add(e.item),
        ),
      );
      controller.swipe(SwipeDirection.right);
      final frames = await settle(tester);
      expect(frames, lessThanOrEqualTo(3));
      expect(ended, ['a']);
    });
  });

  group('lifecycle', () {
    testWidgets('disposing mid-animation is clean', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      controller.swipe(SwipeDirection.right);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(const SizedBox());
      // Nothing keeps ticking: the ticker is gone and frames stop.
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(controller.isAttached, isFalse);
    });

    testWidgets('a stack that never animated disposes cleanly', (tester) async {
      await tester.pumpWidget(swipeApp());
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('swapping the controller re-attaches', (tester) async {
      final first = SwipeCardController();
      final second = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: first));
      await tester.pumpWidget(swipeApp(controller: second));
      expect(first.isAttached, isFalse);
      expect(second.isAttached, isTrue);
      second.swipe(SwipeDirection.right);
      await settle(tester);
      expect(isBuilt('a'), isFalse);
    });
  });
}
