import 'dart:math' as math;

import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

int total(Map<String, int> builds) => builds.values.fold(0, (a, b) => a + b);

void main() {
  group('cost', () {
    testWidgets(
      'no card is rebuilt while the finger moves or a spring settles',
      (tester) async {
        final builds = <String, int>{};
        await tester.pumpWidget(swipeApp(builds: builds));
        final baseline = total(builds);

        final gesture = await tester.startGesture(centerOf(tester, 'a'));
        for (var i = 0; i < 40; i++) {
          await gesture.moveBy(const Offset(2, -1));
          await tester.pump(const Duration(milliseconds: 8));
        }
        expect(total(builds), baseline, reason: 'while dragging');

        await gesture.up(); // short: springs back
        final frames = await settle(tester);
        expect(frames, greaterThan(10));
        expect(total(builds), baseline, reason: 'while settling');
      },
    );

    testWidgets('a commit rebuilds a fixed handful, not one per frame', (
      tester,
    ) async {
      final builds = <String, int>{};
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(builds: builds, controller: controller));
      final baseline = total(builds);

      controller.swipe(SwipeDirection.right);
      final frames = await settle(tester);

      final rebuilds = total(builds) - baseline;
      // Commit and removal each rebuild the visible cards once; that is all.
      expect(frames, greaterThan(15));
      expect(rebuilds, lessThanOrEqualTo(12));
      expect(rebuilds, lessThan(frames));
    });

    testWidgets('nothing runs once everything has settled', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('only the visible cards plus one are in the tree', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: List<String>.generate(50, (i) => 'i$i'),
          controller: controller,
        ),
      );
      expect(find.byType(Card), findsNWidgets(4));
      for (var i = 0; i < 5; i++) {
        controller.swipe(SwipeDirection.right);
        await settle(tester);
      }
      expect(find.byType(Card), findsNWidgets(4)); // nothing accumulates
    });
  });

  group('continuity', () {
    testWidgets('the fling carries the release velocity into the animation', (
      tester,
    ) async {
      await tester.pumpWidget(swipeApp());
      final gesture = await dragWithVelocity(
        tester,
        'a',
        const Offset(120, 0),
        release: false,
      );
      final beforeRelease = centerOf(tester, 'a').dx;
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16)); // move begins
      final atStart = centerOf(tester, 'a').dx;
      await tester.pump(const Duration(milliseconds: 16));
      final oneFrame = centerOf(tester, 'a').dx;

      expect(atStart, closeTo(beforeRelease, 1)); // no jump at release
      // The finger was moving about 1250 px/s, so one frame is ~20px. (A
      // fixed-duration ease-out would start at a fraction of that.)
      final moved = oneFrame - atStart;
      expect(moved, greaterThan(12));
      expect(moved, lessThan(60));
      await settle(tester);
    });

    testWidgets('a fling never jumps or reverses on its way out', (
      tester,
    ) async {
      await tester.pumpWidget(swipeApp());
      await dragWithVelocity(tester, 'a', const Offset(220, 0));
      var previous = centerOf(tester, 'a').dx;
      var worstStep = 0.0;
      var wentBack = false;
      for (var i = 0; i < 250 && isBuilt('a'); i++) {
        await tester.pump(const Duration(milliseconds: 8));
        if (!isBuilt('a')) break;
        final x = centerOf(tester, 'a').dx;
        worstStep = math.max(worstStep, (x - previous).abs());
        if (x < previous - 0.5) wentBack = true;
        previous = x;
      }
      expect(wentBack, isFalse);
      expect(worstStep, lessThan(60)); // per 8 ms frame
    });

    testWidgets('a spring back never jumps, and comes to rest exactly', (
      tester,
    ) async {
      await tester.pumpWidget(swipeApp());
      final rest = centerOf(tester, 'a');
      await dragWithVelocity(
        tester,
        'a',
        const Offset(50, 15),
        duration: const Duration(milliseconds: 400),
        steps: 10,
      ); // slow: not a flick
      var previous = centerOf(tester, 'a');
      var worst = 0.0;
      for (var i = 0; i < 300 && tester.binding.hasScheduledFrame; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        final now = centerOf(tester, 'a');
        worst = math.max(worst, (now - previous).distance);
        previous = now;
      }
      expect(worst, lessThan(30));
      expect(centerOf(tester, 'a'), rest); // exactly, not "close"
    });

    testWidgets('the cards behind do not jump when a card is committed', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      final before = tester.getBottomRight(find.byKey(cardKey('b')));

      controller.swipe(SwipeDirection.right);
      await tester.pump(); // the commit, before any time has passed
      final after = tester.getBottomRight(find.byKey(cardKey('b')));
      expect((after - before).distance, lessThan(0.5));
      await settle(tester);
    });

    testWidgets('nor when the commit comes from a drag that is half-way', (
      tester,
    ) async {
      await tester.pumpWidget(swipeApp());
      final gesture = await tester.startGesture(centerOf(tester, 'a'));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      final before = tester.getBottomRight(find.byKey(cardKey('b')));
      await gesture.up();
      await tester.pump();
      final after = tester.getBottomRight(find.byKey(cardKey('b')));
      expect((after - before).distance, lessThan(0.5));
      await settle(tester);
    });

    testWidgets('a new card fades in behind instead of popping', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      expect(opacityOf(tester, 'd'), 0); // built, invisible

      controller.swipe(SwipeDirection.right);
      await tester.pump();
      var previous = opacityOf(tester, 'd');
      expect(previous, lessThan(0.05)); // no pop on the commit frame
      var worst = 0.0;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final o = opacityOf(tester, 'd');
        expect(o, greaterThanOrEqualTo(previous - 1e-9)); // only fades in
        worst = math.max(worst, o - previous);
        previous = o;
      }
      expect(previous, 1);
      expect(worst, lessThan(0.5));
    });

    testWidgets('undo does not jump the cards behind', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      final before = tester.getBottomRight(find.byKey(cardKey('b')));

      controller.undo();
      await tester.pump();
      final after = tester.getBottomRight(find.byKey(cardKey('b')));
      expect((after - before).distance, lessThan(0.5));
      await settle(tester);
    });
  });

  group('interruption', () {
    testWidgets('a card that is springing back can be caught mid-way', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      await dragWithVelocity(
        tester,
        'a',
        const Offset(50, 0),
        duration: const Duration(milliseconds: 400),
        steps: 10,
      ); // slow: springs back
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 60)); // mid-return
      final caught = centerOf(tester, 'a');

      final gesture = await tester.startGesture(caught);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      // Held: it does not carry on returning under the finger.
      expect((centerOf(tester, 'a') - caught).distance, lessThan(0.5));

      // And it follows the finger from exactly where it was caught.
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();
      expect(centerOf(tester, 'a').dx, closeTo(caught.dx - 50, 1));
      await gesture.up();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the next card can be grabbed while the last one still flies', (
      tester,
    ) async {
      final events = <SwipeEvent<String>>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, onSwipe: events.add),
      );
      final rest = centerOf(tester, 'b');

      controller.swipe(SwipeDirection.right);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40)); // a is mid-flight
      expect(isBuilt('a'), isTrue);

      final gesture = await tester.startGesture(centerOf(tester, 'b'));
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      // b follows the finger straight away, and moves from where it really is.
      expect(centerOf(tester, 'b').dx, lessThan(rest.dx - 15));
      await gesture.up();
      await settle(tester);

      expect(events.map((e) => e.item), ['a']);
      expect(isBuilt('a'), isFalse);
      expect(isBuilt('b'), isTrue);
    });

    testWidgets('a burst of swipes in one frame all land', (tester) async {
      final events = <SwipeEvent<String>>[];
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, onSwipe: events.add),
      );
      for (var i = 0; i < 4; i++) {
        controller.swipe(SwipeDirection.right);
      }
      await settle(tester);
      expect(events.map((e) => e.item), ['a', 'b', 'c', 'd']);
      expect(controller.remaining.value, 1);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('a parent rebuild in the middle of a drag changes nothing', (
      tester,
    ) async {
      await tester.pumpWidget(swipeApp(items: ['a', 'b', 'c', 'd']));
      final gesture = await tester.startGesture(centerOf(tester, 'a'));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      final held = centerOf(tester, 'a');

      await tester.pumpWidget(swipeApp(items: ['a', 'b', 'c', 'd']));
      await tester.pump();
      expect(centerOf(tester, 'a'), held);

      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      expect(centerOf(tester, 'a').dx, closeTo(held.dx + 10, 1));
      await gesture.up();
      await settle(tester);
    });
  });

  group('feel', () {
    testWidgets('the card tilts with where it was grabbed', (tester) async {
      Future<double> tiltGrabbing(Offset from) async {
        await tester.pumpWidget(swipeApp());
        final gesture = await tester.startGesture(from);
        await gesture.moveBy(const Offset(60, 0));
        await tester.pump();
        final card = find.byKey(cardKey('a'));
        final tilt = tester.getTopRight(card).dy - tester.getTopLeft(card).dy;
        await gesture.up();
        await settle(tester);
        return tilt;
      }

      final top = await tiltGrabbing(const Offset(150, 30));
      final bottom = await tiltGrabbing(const Offset(150, 330));
      expect(top, greaterThan(1));
      expect(bottom, lessThan(-1));
    });

    testWidgets('the card follows the finger from the first pixel', (
      tester,
    ) async {
      // Movement before the touch slop is not lost: the card ends up exactly
      // where the finger travelled, not one slop-distance behind it.
      await tester.pumpWidget(swipeApp());
      final start = centerOf(tester, 'a');
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(centerOf(tester, 'a').dx, closeTo(start.dx + 40, 1));
      await gesture.up();
      await settle(tester);
    });

    testWidgets('the animation is the same at 60, 120 and 30 fps', (
      tester,
    ) async {
      Future<Offset> after(Duration step) async {
        final controller = SwipeCardController();
        // A fresh stack each run: the same widget type would keep its state.
        await tester.pumpWidget(
          swipeApp(controller: controller, stackKey: UniqueKey()),
        );
        controller.swipe(SwipeDirection.right);
        await tester.pump(); // commit
        await tester.pump(const Duration(milliseconds: 16)); // move begins
        var elapsed = Duration.zero;
        while (elapsed < const Duration(milliseconds: 96)) {
          await tester.pump(step);
          elapsed += step;
        }
        return centerOf(tester, 'a');
      }

      final at120 = await after(const Duration(milliseconds: 8));
      final at60 = await after(const Duration(milliseconds: 16));
      final at30 = await after(const Duration(milliseconds: 32));
      expect((at120 - at60).distance, lessThan(1));
      expect((at60 - at30).distance, lessThan(1));
    });
  });

  group('stress', () {
    for (final seed in <int>[1, 7, 42, 2024]) {
      testWidgets('random gestures, swipes, undos and resets (seed $seed)', (
        tester,
      ) async {
        final random = math.Random(seed);
        final controller = SwipeCardController();
        final events = <SwipeEvent<String>>[];
        await tester.pumpWidget(
          swipeApp(
            items: List<String>.generate(12, (i) => 'i$i'),
            controller: controller,
            behaviors: {
              SwipeDirection.left: SwipeBehavior<String>.dismiss(),
              SwipeDirection.right: SwipeBehavior<String>.consume(
                target: SwipeTarget(key: targetKey),
              ),
              SwipeDirection.up: SwipeBehavior<String>.springBack(),
              SwipeDirection.down: SwipeBehavior<String>.sendToBack(),
            },
            onSwipe: events.add,
          ),
        );

        Offset randomDelta() => Offset(
          (random.nextDouble() - 0.5) * 600,
          (random.nextDouble() - 0.5) * 600,
        );

        for (var i = 0; i < 160; i++) {
          switch (random.nextInt(7)) {
            case 0:
              await tester.dragFrom(
                Offset(150 + random.nextInt(60) - 30, 150),
                randomDelta(),
              );
            case 1:
              controller.swipe(
                SwipeDirection.values[random.nextInt(4)],
                velocity: random.nextBool() ? null : randomDelta() * 4,
              );
            case 2:
              controller.undo();
            case 3:
              if (random.nextInt(12) == 0) controller.reset();
            case 4:
              final g = await tester.startGesture(
                Offset(100 + random.nextInt(100).toDouble(), 100),
              );
              await tester.pump(Duration(milliseconds: random.nextInt(60)));
              await g.moveBy(randomDelta() / 3);
              await tester.pump(Duration(milliseconds: random.nextInt(60)));
              if (random.nextBool()) await g.moveBy(randomDelta() / 3);
              await g.up();
            default:
              break;
          }
          await tester.pump(Duration(milliseconds: 1 + random.nextInt(120)));
          expect(tester.takeException(), isNull, reason: 'step $i');
        }

        await settle(tester);
        expect(tester.takeException(), isNull);

        // Consistent afterwards: nothing left flying, the tree matches the
        // deck, and the counters agree.
        final remaining = controller.remaining.value;
        expect(remaining, inInclusiveRange(0, 12));
        expect(find.byType(Card), findsNWidgets(math.min(remaining, 4)));
        expect(tester.binding.transientCallbackCount, 0);
        expect(controller.progress.value.isActive, isFalse);
      });
    }
  });
}
