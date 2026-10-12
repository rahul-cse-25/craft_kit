import 'package:craft_kit/craft_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

Map<SwipeDirection, SwipeBehavior<String>> _behaviors() =>
    <SwipeDirection, SwipeBehavior<String>>{
      SwipeDirection.right: SwipeBehavior<String>.consume(
        target: SwipeTarget(key: targetKey, effect: SwipeConsumeEffect.genie),
      ),
      SwipeDirection.left: SwipeBehavior<String>.dismiss(),
    };

void main() {
  testWidgets('every card poured into the button: undo brings them back', (
    tester,
  ) async {
    final controller = SwipeCardController();
    await tester.pumpWidget(
      swipeApp(controller: controller, behaviors: _behaviors()),
    );
    for (var i = 0; i < 5; i++) {
      controller.swipe(SwipeDirection.right);
      await settle(tester);
    }
    expect(controller.remaining.value, 0);
    expect(controller.undoAvailable.value, isTrue);

    controller.undo();
    await settle(tester);
    expect(controller.remaining.value, 1);
    expect(isBuilt('e'), isTrue);

    controller.rewind();
    await settle(tester);
    expect(controller.remaining.value, 5);
    expect(isBuilt('a'), isTrue);
  });

  testWidgets('the same with quick swipes, no waiting in between', (
    tester,
  ) async {
    final controller = SwipeCardController();
    await tester.pumpWidget(
      swipeApp(controller: controller, behaviors: _behaviors()),
    );
    for (var i = 0; i < 5; i++) {
      controller.swipe(SwipeDirection.right);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await settle(tester);
    expect(controller.remaining.value, 0);

    controller.rewind();
    await settle(tester);
    expect(controller.remaining.value, 5);
  });

  testWidgets('rewind straight after the last card went in', (tester) async {
    final controller = SwipeCardController();
    await tester.pumpWidget(
      swipeApp(controller: controller, behaviors: _behaviors()),
    );
    for (var i = 0; i < 5; i++) {
      controller.swipe(SwipeDirection.right);
      await settle(tester);
    }
    controller.rewind();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await settle(tester);
    expect(controller.remaining.value, 5);
  });
}
