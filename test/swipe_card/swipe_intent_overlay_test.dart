import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

const _intents = <SwipeIntent>[
  SwipeIntent(
    direction: SwipeDirection.right,
    color: Colors.green,
    icon: Icon(Icons.favorite_rounded, key: ValueKey('like-icon')),
    label: 'Like',
  ),
  SwipeIntent(
    direction: SwipeDirection.left,
    color: Colors.red,
    icon: Icon(Icons.close_rounded, key: ValueKey('nope-icon')),
    label: 'Nope',
  ),
];

Widget host(SwipeProgress progress) => MaterialApp(
  home: SizedBox(
    width: 300,
    height: 400,
    child: SwipeIntentOverlay(progress: progress, intents: _intents),
  ),
);

void main() {
  testWidgets('draws nothing while the card is at rest', (tester) async {
    await tester.pumpWidget(host(SwipeProgress.zero));
    expect(find.byKey(const ValueKey('like-icon')), findsNothing);
    expect(find.text('LIKE'), findsNothing);
  });

  testWidgets('shows only the intents of the directions being dragged', (
    tester,
  ) async {
    await tester.pumpWidget(host(const SwipeProgress(right: 0.5)));
    expect(find.byKey(const ValueKey('like-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('nope-icon')), findsNothing);
  });

  testWidgets('the word appears only once releasing would commit', (
    tester,
  ) async {
    await tester.pumpWidget(host(const SwipeProgress(right: 0.6)));
    expect(find.text('LIKE'), findsNothing);
    await tester.pumpWidget(host(const SwipeProgress(right: 1)));
    expect(find.text('LIKE'), findsOneWidget);
  });

  testWidgets('two directions cross-fade instead of one replacing the other', (
    tester,
  ) async {
    await tester.pumpWidget(host(const SwipeProgress(right: 0.4, left: 0.2)));
    expect(find.byKey(const ValueKey('like-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('nope-icon')), findsOneWidget);
  });

  testWidgets('never takes touches from the card', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: <Widget>[
            GestureDetector(onTap: () => taps++),
            const SwipeIntentOverlay(
              progress: SwipeProgress(right: 1),
              intents: _intents,
            ),
          ],
        ),
      ),
    );
    await tester.tapAt(const Offset(200, 300));
    expect(taps, 1);
  });

  testWidgets('works as a stack overlay and follows a real drag', (
    tester,
  ) async {
    await tester.pumpWidget(
      swipeApp(
        overlayBuilder:
            (context, progress) =>
                SwipeIntentOverlay(progress: progress, intents: _intents),
      ),
    );
    expect(find.byKey(const ValueKey('like-icon')), findsNothing);
    final gesture = await tester.startGesture(centerOf(tester, 'a'));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    expect(find.byKey(const ValueKey('like-icon')), findsOneWidget);
    await gesture.up();
    await settle(tester);
    expect(find.byKey(const ValueKey('like-icon')), findsNothing);
  });
}
