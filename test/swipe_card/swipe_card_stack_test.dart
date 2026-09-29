import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required List<String> items,
  SwipeCardController? controller,
  void Function(String, int, SwipeDirection)? onSwipe,
  VoidCallback? onEnd,
  Set<SwipeDirection> allowed = const {
    SwipeDirection.left,
    SwipeDirection.right,
  },
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          height: 400,
          child: SwipeCardStack<String>(
            items: items,
            controller: controller,
            onSwipe: onSwipe,
            onEnd: onEnd,
            allowedDirections: allowed,
            itemBuilder: (context, item, index) =>
                Card(child: Center(child: Text(item))),
            emptyBuilder: (context) => const Text('empty'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('dragging past the threshold swipes the card', (tester) async {
    final swipes = <String>[];
    await tester.pumpWidget(
      _app(
        items: ['a', 'b'],
        onSwipe: (item, i, d) => swipes.add('$item:${d.name}'),
      ),
    );

    await tester.drag(find.text('a'), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(swipes, ['a:right']);
    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('a short drag snaps back', (tester) async {
    final swipes = <String>[];
    await tester.pumpWidget(
      _app(items: ['a', 'b'], onSwipe: (item, i, d) => swipes.add(item)),
    );

    await tester.drag(find.text('a'), const Offset(-30, 0));
    await tester.pumpAndSettle();

    expect(swipes, isEmpty);
    expect(find.text('a'), findsOneWidget);
  });

  testWidgets('disallowed direction snaps back', (tester) async {
    final swipes = <String>[];
    await tester.pumpWidget(
      _app(items: ['a'], onSwipe: (item, i, d) => swipes.add(item)),
    );

    await tester.drag(find.text('a'), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(swipes, isEmpty);
    expect(find.text('a'), findsOneWidget);
  });

  testWidgets('controller swipes, undoes, and onEnd fires', (tester) async {
    final controller = SwipeCardController();
    var ended = 0;
    await tester.pumpWidget(
      _app(items: ['a'], controller: controller, onEnd: () => ended++),
    );

    controller.swipe(SwipeDirection.left);
    await tester.pumpAndSettle();
    expect(ended, 1);
    expect(find.text('empty'), findsOneWidget);
    expect(controller.canUndo, isTrue);

    controller.undo();
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
    expect(controller.canUndo, isFalse);
  });
}
