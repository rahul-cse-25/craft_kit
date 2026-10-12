import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

void main() {
  testWidgets('a card dragged into the button comes back with a drag down', (
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
          SwipeDirection.down: SwipeBehavior<String>.undo(),
        },
      ),
    );

    for (var i = 0; i < 3; i++) {
      await dragWithVelocity(tester, 'a', const Offset(260, 20));
      await settle(tester);
      expect(controller.remaining.value, 4, reason: 'dragged $i');

      // The new top card is dragged down: the previous one comes back.
      await dragWithVelocity(tester, 'b', const Offset(0, 260));
      await settle(tester);
      expect(controller.remaining.value, 5, reason: 'undone $i');
      expect(undone.length, i + 1, reason: 'callback $i');
      expect(isBuilt('a'), isTrue);
    }
  });
}
