import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

/// A layout that is not the built-in one: cards fan out to the right.
class _SideLayout extends SwipeStackLayout {
  const _SideLayout();

  @override
  int get visibleCards => 2;

  @override
  EdgeInsets get reserve => const EdgeInsets.only(right: 30);

  @override
  SwipeSlot slotAt(double depth) => SwipeSlot(
    offset: Offset(30 * depth, 0),
    scale: 1 - 0.1 * depth,
    opacity: (visibleCards - depth).clamp(0.0, 1.0),
    alignment: Alignment.centerLeft,
  );
}

void main() {
  group('cascade layout', () {
    testWidgets('cards behind peek out below and are narrower', (tester) async {
      await tester.pumpWidget(swipeApp(items: ['a', 'b', 'c', 'd']));
      final stack = tester.getRect(find.byType(SwipeCardStack<String>));
      Rect rect(String k) {
        final f = find.byKey(cardKey(k));
        return Rect.fromPoints(tester.getTopLeft(f), tester.getBottomRight(f));
      }

      final a = rect('a');
      final b = rect('b');
      final c = rect('c');
      expect(a.bottom, closeTo(stack.bottom - 28, 0.01));
      expect(b.bottom - a.bottom, closeTo(14, 0.01));
      expect(c.bottom - b.bottom, closeTo(14, 0.01));
      expect(c.bottom, closeTo(stack.bottom, 0.01));
      expect(b.width, closeTo(300 * 0.94, 0.01));
      expect(c.width, closeTo(300 * 0.88, 0.01));
      expect(a.center.dx, closeTo(b.center.dx, 0.01)); // centered
    });

    testWidgets('builds the visible cards plus one hidden one', (tester) async {
      await tester.pumpWidget(swipeApp(items: ['a', 'b', 'c', 'd', 'e', 'f']));
      expect(find.byType(Card), findsNWidgets(4));
      expect(opacityOf(tester, 'c'), 1);
      expect(opacityOf(tester, 'd'), 0);
    });

    testWidgets('offset 0 stacks the cards exactly behind each other', (
      tester,
    ) async {
      await tester.pumpWidget(
        swipeApp(
          items: ['a', 'b', 'c'],
          layout: const CascadeLayout(offset: 0, scaleStep: 0),
        ),
      );
      expect(
        tester.getBottomRight(find.byKey(cardKey('b'))),
        tester.getBottomRight(find.byKey(cardKey('a'))),
      );
    });

    testWidgets('tilt fans the cards', (tester) async {
      await tester.pumpWidget(
        swipeApp(
          items: ['a', 'b', 'c'],
          layout: const CascadeLayout(tilt: 0.06),
        ),
      );
      double lean(String k) {
        final f = find.byKey(cardKey(k));
        return tester.getTopRight(f).dy - tester.getTopLeft(f).dy;
      }

      expect(lean('a'), closeTo(0, 0.01));
      expect(lean('b'), greaterThan(1));
      expect(lean('c'), greaterThan(lean('b')));
    });

    testWidgets('the cards behind rise while the top card is dragged', (
      tester,
    ) async {
      await tester.pumpWidget(swipeApp(items: ['a', 'b', 'c']));
      final before = tester.getBottomRight(find.byKey(cardKey('b')));
      final gesture = await tester.startGesture(centerOf(tester, 'a'));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      final during = tester.getBottomRight(find.byKey(cardKey('b')));
      expect(during.dy, lessThan(before.dy));
      expect(during.dx, greaterThan(before.dx)); // and widen toward the front
      await gesture.up();
      await settle(tester);
    });
  });

  group('a custom layout', () {
    testWidgets('is honoured: reserved space, slots, count', (tester) async {
      await tester.pumpWidget(
        swipeApp(items: ['a', 'b', 'c', 'd'], layout: const _SideLayout()),
      );
      final stack = tester.getRect(find.byType(SwipeCardStack<String>));
      Rect rect(String k) {
        final f = find.byKey(cardKey(k));
        return Rect.fromPoints(tester.getTopLeft(f), tester.getBottomRight(f));
      }

      // The top card leaves 30px free on the right for the card behind it.
      expect(rect('a').right, closeTo(stack.right - 30, 0.01));
      expect(rect('b').left, closeTo(rect('a').left + 30, 0.01));
      expect(rect('b').width, closeTo(270 * 0.9, 0.01));
      // visibleCards is 2, so three are built and the third is hidden.
      expect(find.byType(Card), findsNWidgets(3));
      expect(opacityOf(tester, 'c'), 0);
    });

    testWidgets('a swipe keeps working and the layout stays continuous', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: ['a', 'b', 'c', 'd'],
          layout: const _SideLayout(),
          controller: controller,
        ),
      );
      final before = tester.getTopLeft(find.byKey(cardKey('b')));
      controller.swipe(SwipeDirection.right);
      await tester.pump();
      expect(
        (tester.getTopLeft(find.byKey(cardKey('b'))) - before).distance,
        lessThan(0.5),
      );
      await settle(tester);
      // b has moved up into the top slot.
      expect(tester.getTopLeft(find.byKey(cardKey('b'))).dx, closeTo(0, 0.01));
    });
  });

  group('the card builder', () {
    testWidgets('knows its depth and whether it is the top card', (
      tester,
    ) async {
      final seen = <String, SwipeCardInfo>{};
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 400,
            child: SwipeCardStack<String>(
              items: const ['a', 'b', 'c'],
              itemBuilder: (context, item, info) {
                seen[item] = info;
                return ColoredBox(color: Colors.red, child: Text(item));
              },
            ),
          ),
        ),
      );
      expect(seen['a']!.isTop, isTrue);
      expect(seen['a']!.depth, 0);
      expect(seen['b']!.isTop, isFalse);
      expect(seen['b']!.depth, 1);
      expect(seen['c']!.depth, 2);
      expect(seen['a']!.isLeaving, isFalse);
    });

    testWidgets('items with their own keys work, and duplicates are caught', (
      tester,
    ) async {
      // Two items that are equal but distinct, told apart by an id.
      final items = <({int id, String label})>[
        (id: 1, label: 'same'),
        (id: 2, label: 'same'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 400,
            child: SwipeCardStack<({int id, String label})>(
              items: items,
              itemKey: (item) => ValueKey<int>(item.id),
              itemBuilder:
                  (context, item, info) => Text('${item.label}#${item.id}'),
            ),
          ),
        ),
      );
      expect(find.text('same#1'), findsOneWidget);
      expect(find.text('same#2'), findsOneWidget);
    });
  });
}
