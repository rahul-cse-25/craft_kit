import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

/// The app of [swipeApp] with a reacting widget reporting what it sees.
Widget reactionApp(
  SwipeCardController controller,
  List<SwipeReactionState> states, {
  SwipeDirection direction = SwipeDirection.right,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: <Widget>[
          SizedBox(
            width: 300,
            height: 400,
            child: SwipeCardStack<String>(
              items: const ['a', 'b', 'c'],
              controller: controller,
              behaviors: {
                SwipeDirection.right: SwipeBehavior<String>.consume(
                  target: SwipeTarget(key: targetKey),
                ),
                SwipeDirection.left: SwipeBehavior<String>.dismiss(),
              },
              itemBuilder:
                  (context, item, info) =>
                      Card(key: cardKey(item), child: Text(item)),
            ),
          ),
          SwipeReaction(
            controller: controller,
            direction: direction,
            builder: (context, state, child) {
              states.add(state);
              return SizedBox(key: targetKey, width: 60, height: 60);
            },
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('approach follows the drag toward its direction only', (
    tester,
  ) async {
    final controller = SwipeCardController();
    final states = <SwipeReactionState>[];
    await tester.pumpWidget(reactionApp(controller, states));

    final gesture = await tester.startGesture(centerOf(tester, 'a'));
    await gesture.moveBy(const Offset(45, 0));
    await tester.pump();
    expect(states.last.approach, closeTo(0.5, 0.1));

    await gesture.moveBy(const Offset(-120, 0)); // now toward the left
    await tester.pump();
    expect(states.last.approach, 0);
    await gesture.up();
    await settle(tester);
  });

  testWidgets('arrival rises while the card is consumed, then eases out', (
    tester,
  ) async {
    final controller = SwipeCardController();
    final states = <SwipeReactionState>[];
    await tester.pumpWidget(reactionApp(controller, states));

    controller.swipe(SwipeDirection.right);
    await tester.pump();
    var peak = 0.0;
    var previous = 0.0;
    var rose = true;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final arrival = states.last.arrival;
      if (arrival < previous - 1e-9 && arrival > 0.02 && previous < 0.98) {
        rose = false; // fell before it arrived
      }
      if (arrival > peak) peak = arrival;
      previous = arrival;
      if (!isBuilt('a')) break;
    }
    expect(rose, isTrue);
    expect(peak, greaterThan(0.9));

    await settle(tester);
    expect(states.last.arrival, 0); // eased back
  });

  testWidgets('a reaction for another direction is not affected', (
    tester,
  ) async {
    final controller = SwipeCardController();
    final states = <SwipeReactionState>[];
    await tester.pumpWidget(
      reactionApp(controller, states, direction: SwipeDirection.left),
    );
    controller.swipe(SwipeDirection.right); // consumed into the right target
    await settle(tester);
    expect(states.every((s) => s.arrival == 0), isTrue);
  });

  testWidgets('the child is not rebuilt as the card moves', (tester) async {
    final controller = SwipeCardController();
    var childBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              SizedBox(
                width: 300,
                height: 400,
                child: SwipeCardStack<String>(
                  items: const ['a', 'b'],
                  controller: controller,
                  itemBuilder:
                      (context, item, info) => Card(key: cardKey(item)),
                ),
              ),
              SwipeReaction(
                controller: controller,
                direction: SwipeDirection.right,
                builder: (context, state, child) => child!,
                child: Builder(
                  builder: (context) {
                    childBuilds++;
                    return const SizedBox(width: 10, height: 10);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final baseline = childBuilds;
    final gesture = await tester.startGesture(centerOf(tester, 'a'));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(8, 0));
      await tester.pump();
    }
    expect(childBuilds, baseline);
    await gesture.up();
    await settle(tester);
  });

  testWidgets('disposing a reaction mid-way is clean', (tester) async {
    final controller = SwipeCardController();
    final states = <SwipeReactionState>[];
    await tester.pumpWidget(reactionApp(controller, states));
    controller.swipe(SwipeDirection.right);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
