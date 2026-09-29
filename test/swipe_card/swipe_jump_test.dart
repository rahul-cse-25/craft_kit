import 'package:craft_kit/craft_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

void main() {
  group('initialIndex', () {
    testWidgets('starts with that card on top and the earlier ones hidden', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(controller: controller, initialIndex: 2),
      );
      await tester.pump();

      expect(isBuilt('a'), isFalse);
      expect(isBuilt('b'), isFalse);
      expect(isBuilt('c'), isTrue);
      expect(controller.remaining.value, 3);
      expect(controller.undoAvailable.value, isTrue);
    });

    testWidgets('undo brings the earlier cards back, sliding in from above', (
      tester,
    ) async {
      final controller = SwipeCardController();
      final undone = <SwipeEvent<String>>[];
      await tester.pumpWidget(
        swipeApp(controller: controller, initialIndex: 2, onUndo: undone.add),
      );
      await tester.pump();
      final rest = centerOf(tester, 'c');

      controller.undo();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 48));
      expect(centerOf(tester, 'b').dy, lessThan(rest.dy - 100));

      await settle(tester);
      expect(centerOf(tester, 'b'), rest);
      expect(undone.map((e) => e.item), ['b']);

      controller.undo();
      await settle(tester);
      controller.undo(); // nothing left to bring back
      await settle(tester);
      expect(undone.map((e) => e.item), ['b', 'a']);
      expect(controller.undoAvailable.value, isFalse);
      expect(controller.remaining.value, 5);
    });

    testWidgets('an index past the end shows the empty state', (tester) async {
      await tester.pumpWidget(swipeApp(initialIndex: 9));
      await tester.pump();
      expect(find.text('empty'), findsOneWidget);
    });

    testWidgets('the history limit still applies', (tester) async {
      final controller = SwipeCardController();
      final undone = <SwipeEvent<String>>[];
      await tester.pumpWidget(
        swipeApp(
          controller: controller,
          initialIndex: 4,
          historyLimit: 2,
          onUndo: undone.add,
        ),
      );
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        controller.undo();
        await settle(tester);
      }
      expect(undone.map((e) => e.item), ['d', 'c']);
    });

    testWidgets('a parent rebuild never brings the hidden cards back', (
      tester,
    ) async {
      await tester.pumpWidget(swipeApp(initialIndex: 2));
      await tester.pump();
      await tester.pumpWidget(
        swipeApp(initialIndex: 2, items: const ['a', 'b', 'c', 'd', 'e', 'f']),
      );
      await tester.pump();
      expect(isBuilt('a'), isFalse);
      expect(isBuilt('c'), isTrue);
    });
  });

  group('jumpTo', () {
    testWidgets('makes the card the top card, instantly', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      await tester.pump();
      final rest = centerOf(tester, 'a');

      expect(controller.jumpTo(itemKeyOf('d')), isTrue);
      await tester.pump();

      expect(isBuilt('a'), isFalse);
      expect(centerOf(tester, 'd'), rest);
      expect(controller.remaining.value, 2);
      expect(controller.undoAvailable.value, isTrue);
    });

    testWidgets('can go back to an earlier card', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      controller.swipe(SwipeDirection.right);
      await settle(tester);

      expect(controller.jumpTo(itemKeyOf('a')), isTrue);
      await tester.pump();
      expect(isBuilt('a'), isTrue);
      expect(controller.remaining.value, 5);
      expect(controller.undoAvailable.value, isFalse);
    });

    testWidgets('an unknown key, or the card already on top, changes nothing', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      await tester.pump();
      expect(controller.jumpTo(itemKeyOf('zzz')), isFalse);
      expect(controller.jumpTo(itemKeyOf('a')), isTrue);
      expect(controller.remaining.value, 5);
    });

    testWidgets('is refused while a card is held', (tester) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      final gesture = await tester.startGesture(centerOf(tester, 'a'));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(controller.jumpTo(itemKeyOf('c')), isFalse);
      await gesture.up();
      await settle(tester);
    });

    testWidgets('asks for more cards when the jump lands near the end', (
      tester,
    ) async {
      final controller = SwipeCardController();
      final asked = <int>[];
      await tester.pumpWidget(
        swipeApp(controller: controller, onNeedMore: asked.add),
      );
      await tester.pump();
      controller.jumpTo(itemKeyOf('d'));
      await tester.pump();
      await tester.pump();
      expect(asked, [2]);
    });

    testWidgets('swiping still works afterwards', (tester) async {
      final controller = SwipeCardController();
      final events = <SwipeEvent<String>>[];
      await tester.pumpWidget(
        swipeApp(controller: controller, onSwipe: events.add),
      );
      controller.jumpTo(itemKeyOf('c'));
      await tester.pump();
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      expect(events.single.item, 'c');
      expect(centerOf(tester, 'd'), isNotNull);
    });
  });
}
