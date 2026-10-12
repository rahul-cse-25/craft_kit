import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

void main() {
  testWidgets('an undo during the flight leaves nothing behind', (
    tester,
  ) async {
    final controller = SwipeCardController();
    await tester.pumpWidget(
      swipeApp(
        controller: controller,
        behaviors: <SwipeDirection, SwipeBehavior<String>>{
          SwipeDirection.right: SwipeBehavior<String>.consume(
            target: SwipeTarget(
              key: targetKey,
              effect: SwipeConsumeEffect.genie,
            ),
          ),
        },
      ),
    );
    // like, undo straight away (mid-flight)
    controller.swipe(SwipeDirection.right);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    controller.undo();
    await settle(tester);
    expect(controller.remaining.value, 5);

    // rewind of a few
    for (var i = 0; i < 3; i++) {
      controller.swipe(SwipeDirection.right);
      await settle(tester);
    }
    controller.rewind();
    await settle(tester);
    expect(controller.remaining.value, 5);

    // and now plain likes and undos with fixed pauses
    for (var i = 0; i < 4; i++) {
      controller.swipe(SwipeDirection.right);
      await tester.pump(const Duration(seconds: 2));
      expect(controller.remaining.value, 4, reason: 'like $i');
      controller.undo();
      await tester.pump(const Duration(seconds: 2));
      expect(controller.remaining.value, 5, reason: 'undo $i');
    }
  });
}
