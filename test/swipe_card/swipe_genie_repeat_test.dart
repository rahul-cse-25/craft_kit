import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

void main() {
  testWidgets('like then undo works again and again, with the genie', (
    tester,
  ) async {
    final controller = SwipeCardController();
    final undone = <String>[];
    await tester.pumpWidget(
      swipeApp(
        controller: controller,
        onUndo: (e) => undone.add(e.item),
        behaviors: <SwipeDirection, SwipeBehavior<String>>{
          SwipeDirection.right: SwipeBehavior<String>.consume(
            target: SwipeTarget(
              key: targetKey,
              effect: SwipeConsumeEffect.genie,
            ),
          ),
          SwipeDirection.left: SwipeBehavior<String>.dismiss(),
        },
      ),
    );
    for (var i = 0; i < 6; i++) {
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      expect(controller.remaining.value, 4, reason: 'after like $i');
      expect(controller.undoAvailable.value, isTrue, reason: 'like $i');
      controller.undo();
      await settle(tester);
      expect(controller.remaining.value, 5, reason: 'after undo $i');
      expect(undone.length, i + 1, reason: 'undo callback $i');
    }
  });

  testWidgets('three likes, three undos, then a rewind', (tester) async {
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
    for (var i = 0; i < 3; i++) {
      controller.swipe(SwipeDirection.right);
      await settle(tester);
    }
    expect(controller.remaining.value, 2);
    for (var i = 0; i < 3; i++) {
      controller.undo();
      await settle(tester);
    }
    expect(controller.remaining.value, 5);
    for (var i = 0; i < 4; i++) {
      controller.swipe(SwipeDirection.right);
      await settle(tester);
    }
    controller.rewind();
    await settle(tester);
    expect(controller.remaining.value, 5);
  });
}
