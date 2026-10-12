import 'package:craft_kit/craft_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

const _eight = <String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

Map<SwipeDirection, SwipeBehavior<String>> _behaviors() =>
    <SwipeDirection, SwipeBehavior<String>>{
      SwipeDirection.right: SwipeBehavior<String>.consume(
        target: SwipeTarget(key: targetKey, effect: SwipeConsumeEffect.genie),
      ),
    };

void main() {
  testWidgets('eight liked, rewind straight away', (tester) async {
    final controller = SwipeCardController();
    await tester.pumpWidget(
      swipeApp(items: _eight, controller: controller, behaviors: _behaviors()),
    );
    for (var i = 0; i < 8; i++) {
      controller.swipe(SwipeDirection.right);
      await tester.pump(const Duration(milliseconds: 700));
    }
    await settle(tester);
    expect(controller.remaining.value, 0);
    controller.rewind();
    await settle(tester);
    expect(controller.remaining.value, 8);
  });

  testWidgets('eight liked, undo, then rewind while it is still coming', (
    tester,
  ) async {
    final controller = SwipeCardController();
    await tester.pumpWidget(
      swipeApp(items: _eight, controller: controller, behaviors: _behaviors()),
    );
    for (var i = 0; i < 8; i++) {
      controller.swipe(SwipeDirection.right);
      await tester.pump(const Duration(milliseconds: 700));
    }
    await settle(tester);
    controller.undo();
    await settle(tester);
    expect(controller.remaining.value, 1);
    controller.rewind();
    await settle(tester);
    expect(controller.remaining.value, 8);
  });

  testWidgets('undo and rewind with slow frames, like a weak device', (
    tester,
  ) async {
    final controller = SwipeCardController();
    await tester.pumpWidget(
      swipeApp(items: _eight, controller: controller, behaviors: _behaviors()),
    );
    for (var i = 0; i < 8; i++) {
      controller.swipe(SwipeDirection.right);
      await tester.pump(const Duration(milliseconds: 700));
    }
    await tester.pump(const Duration(seconds: 3));
    controller.undo();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.remaining.value, 1);
    controller.rewind();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(controller.remaining.value, 8);
  });
}
