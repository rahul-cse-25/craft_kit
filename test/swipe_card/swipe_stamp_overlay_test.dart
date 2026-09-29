import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

const _stamps = <SwipeStamp>[
  SwipeStamp(
    direction: SwipeDirection.right,
    label: 'LIKE',
    color: Colors.green,
  ),
  SwipeStamp(direction: SwipeDirection.left, label: 'NOPE', color: Colors.red),
];

Widget host(SwipeProgress progress) =>
    MaterialApp(home: SwipeStampOverlay(progress: progress, stamps: _stamps));

void main() {
  testWidgets('draws nothing at rest', (tester) async {
    await tester.pumpWidget(host(SwipeProgress.zero));
    expect(find.text('LIKE'), findsNothing);
    expect(find.text('NOPE'), findsNothing);
  });

  testWidgets('a direction fades in with its own progress', (tester) async {
    await tester.pumpWidget(host(const SwipeProgress(right: 0.4)));
    expect(find.text('LIKE'), findsOneWidget);
    expect(find.text('NOPE'), findsNothing);
    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, closeTo(0.4, 1e-9));
  });

  testWidgets('sits in the corner away from the drag', (tester) async {
    await tester.pumpWidget(host(const SwipeProgress(right: 1)));
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final at = tester.getCenter(find.text('LIKE'));
    expect(at.dx, lessThan(size.width / 2));
    expect(at.dy, lessThan(size.height / 2));
  });

  testWidgets('works as a stack overlay', (tester) async {
    await tester.pumpWidget(
      swipeApp(
        overlayBuilder:
            (context, progress) =>
                SwipeStampOverlay(progress: progress, stamps: _stamps),
      ),
    );
    final gesture = await tester.startGesture(centerOf(tester, 'a'));
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(find.text('NOPE'), findsOneWidget);
    await gesture.up();
    await settle(tester);
    expect(find.text('NOPE'), findsNothing);
  });
}
