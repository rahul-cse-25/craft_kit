import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Key of the card built for [item].
Key cardKey(String item) => ValueKey<String>('card-$item');

/// The stack's key for [item] (its `ValueKey`).
Key itemKeyOf(String item) => ValueKey<String>(item);

/// A target placed under the 300x400 stack, at x 0..60, y 400..460.
final GlobalKey targetKey = GlobalKey(debugLabel: 'target');

/// A stack of 300x400 in the top-left corner, with a target button below it.
///
/// [builds] counts how often each card is built.
Widget swipeApp({
  List<String> items = const <String>['a', 'b', 'c', 'd', 'e'],
  Map<SwipeDirection, SwipeBehavior<String>>? behaviors,
  SwipeCardController? controller,
  SwipeStackLayout layout = const CascadeLayout(),
  SwipePhysics physics = const SwipePhysics(),
  SwipeHaptics haptics = SwipeHaptics.none,
  SwipeCallback<String>? onSwipe,
  SwipeCallback<String>? onSwipeEnd,
  SwipeCallback<String>? onUndo,
  VoidCallback? onEnd,
  void Function(int remaining)? onNeedMore,
  SwipePreloadCallback<String>? onPreload,
  SwipeOverlayBuilder? overlayBuilder,
  Map<String, int>? builds,
  bool enabled = true,
  bool reduceMotion = false,
  int historyLimit = 20,
  int initialIndex = 0,
  bool autofocus = false,
  Key? stackKey,
}) {
  return MaterialApp(
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 300,
              height: 400,
              child: SwipeCardStack<String>(
                key: stackKey,
                items: items,
                controller: controller,
                behaviors: behaviors,
                layout: layout,
                physics: physics,
                haptics: haptics,
                onSwipe: onSwipe,
                onSwipeEnd: onSwipeEnd,
                onUndo: onUndo,
                onEnd: onEnd,
                onNeedMore: onNeedMore,
                onPreload: onPreload,
                overlayBuilder: overlayBuilder,
                enabled: enabled,
                historyLimit: historyLimit,
                initialIndex: initialIndex,
                autofocus: autofocus,
                emptyBuilder: (context) => const Center(child: Text('empty')),
                itemBuilder: (context, item, info) {
                  if (builds != null) builds[item] = (builds[item] ?? 0) + 1;
                  return Card(
                    key: cardKey(item),
                    child: Center(child: Text(item)),
                  );
                },
              ),
            ),
            SizedBox(key: targetKey, width: 60, height: 60),
          ],
        ),
      ),
    ),
  );
}

/// Where the card for [item] is on screen (transforms included).
Offset centerOf(WidgetTester tester, String item) =>
    tester.getCenter(find.byKey(cardKey(item)));

bool isBuilt(String item) => find.byKey(cardKey(item)).evaluate().isNotEmpty;

/// The opacity applied to the card for [item] by the stack.
double opacityOf(WidgetTester tester, String item) =>
    tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(cardKey(item)),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

/// Pumps frames of [step] until nothing is animating, returning the frames.
Future<int> settle(
  WidgetTester tester, {
  Duration step = const Duration(milliseconds: 16),
  int limit = 400,
}) async {
  var frames = 0;
  await tester.pump();
  while (tester.binding.hasScheduledFrame && frames < limit) {
    await tester.pump(step);
    frames++;
  }
  return frames;
}

/// Drags [item] by [delta] in steps that carry timestamps, so the release has
/// a real velocity of about [delta] over [duration].
Future<TestGesture> dragWithVelocity(
  WidgetTester tester,
  String item,
  Offset delta, {
  Duration duration = const Duration(milliseconds: 96),
  int steps = 6,
  bool release = true,
}) async {
  final gesture = await tester.startGesture(centerOf(tester, item));
  final stepDelta = delta / steps.toDouble();
  final stepTime = duration ~/ steps;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveBy(stepDelta, timeStamp: stepTime * i);
    await tester.pump(stepTime);
  }
  if (release) await gesture.up();
  return gesture;
}
