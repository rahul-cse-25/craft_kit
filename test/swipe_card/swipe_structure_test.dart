import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

/// A card with state of its own, like a video, a text field or an image that
/// is still loading. Counts how often its state is created.
class _Probe extends StatefulWidget {
  const _Probe(this.item, this.inits, this.disposes);

  final String item;
  final Map<String, int> inits;
  final Map<String, int> disposes;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.inits[widget.item] = (widget.inits[widget.item] ?? 0) + 1;
  }

  @override
  void dispose() {
    widget.disposes[widget.item] = (widget.disposes[widget.item] ?? 0) + 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.item);
}

Widget probeApp({
  required SwipeCardController controller,
  required Map<String, int> inits,
  required Map<String, int> disposes,
  Map<SwipeDirection, SwipeBehavior<String>>? behaviors,
  List<String> items = const ['a', 'b', 'c', 'd', 'e'],
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          height: 400,
          child: SwipeCardStack<String>(
            items: items,
            controller: controller,
            behaviors: behaviors,
            itemBuilder:
                (context, item, info) => Card(
                  key: cardKey(item),
                  child: _Probe(item, inits, disposes),
                ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('a card keeps its state on its whole journey', () {
    testWidgets('from the back, to the top, to gone', (tester) async {
      final inits = <String, int>{};
      final disposes = <String, int>{};
      final controller = SwipeCardController();
      await tester.pumpWidget(
        probeApp(controller: controller, inits: inits, disposes: disposes),
      );
      // a, b, c, d are built (three shown and one hidden).
      expect(inits, {'a': 1, 'b': 1, 'c': 1, 'd': 1});

      for (var i = 0; i < 3; i++) {
        controller.swipe(SwipeDirection.right);
        await settle(tester);
      }
      // b, c and d moved up through every role (back -> top -> leaving), and
      // none was rebuilt from scratch on the way.
      for (final k in ['a', 'b', 'c', 'd']) {
        expect(inits[k], 1, reason: 'state of $k was recreated');
      }
      // e joined at the back once, and the three that left were disposed once.
      expect(inits['e'], 1);
      expect(disposes, {'a': 1, 'b': 1, 'c': 1});
    });

    testWidgets('through a spring back and an undo', (tester) async {
      final inits = <String, int>{};
      final disposes = <String, int>{};
      final controller = SwipeCardController();
      await tester.pumpWidget(
        probeApp(
          controller: controller,
          inits: inits,
          disposes: disposes,
          behaviors: {
            SwipeDirection.right: SwipeBehavior<String>.dismiss(),
            SwipeDirection.up: SwipeBehavior<String>.springBack(),
          },
        ),
      );
      controller.swipe(SwipeDirection.up); // springs back
      await settle(tester);
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      // a left and was disposed once; b is the top card and was never rebuilt.
      expect(inits['b'], 1);
      expect(disposes['a'], 1);

      controller.undo(); // a comes back: a new card, so a new state
      await settle(tester);
      expect(inits['a'], 2);
      expect(inits['b'], 1); // but b did not care
    });

    testWidgets('only the top card is exposed to accessibility', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = SwipeCardController();
      await tester.pumpWidget(
        probeApp(controller: controller, inits: {}, disposes: {}),
      );
      final actions = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.customSemanticsActions?.isNotEmpty ?? false),
      );
      expect(actions, findsOneWidget);
      // Cards behind are not announced at all.
      expect(find.bySemanticsLabel('b'), findsNothing);
      handle.dispose();
    });
  });

  group('rebuilding cards', () {
    testWidgets('a swipe builds only the cards that changed place', (
      tester,
    ) async {
      final builds = <String, int>{};
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: List<String>.generate(30, (i) => 'i$i'),
          controller: controller,
          builds: builds,
        ),
      );
      final baseline = builds.values.fold(0, (a, b) => a + b);

      controller.swipe(SwipeDirection.right);
      await tester.pump(); // the commit
      final atCommit = builds.values.fold(0, (a, b) => a + b);
      await settle(tester);
      final atEnd = builds.values.fold(0, (a, b) => a + b);

      // The commit rebuilds the cards whose role changed: the leaving card, the
      // three that move up, and the one that appears (five).
      expect(atCommit - baseline, lessThanOrEqualTo(5));
      // Finishing the animation removes the leaving card without rebuilding
      // any other: it reuses the cards it already built.
      expect(atEnd - atCommit, 0);
    });

    testWidgets('twenty swipes cost a small, steady number of builds', (
      tester,
    ) async {
      final builds = <String, int>{};
      final controller = SwipeCardController();
      await tester.pumpWidget(
        swipeApp(
          items: List<String>.generate(40, (i) => 'i$i'),
          controller: controller,
          builds: builds,
        ),
      );
      final baseline = builds.values.fold(0, (a, b) => a + b);
      for (var i = 0; i < 20; i++) {
        controller.swipe(SwipeDirection.right);
        await settle(tester);
      }
      final perSwipe = (builds.values.fold(0, (a, b) => a + b) - baseline) / 20;
      expect(perSwipe, lessThanOrEqualTo(5));
    });

    testWidgets(
      'a parent rebuild does rebuild the cards (so they can change)',
      (tester) async {
        final builds = <String, int>{};
        await tester.pumpWidget(swipeApp(builds: builds));
        final before = builds['a']!;
        await tester.pumpWidget(swipeApp(builds: builds)); // same widget type
        await tester.pump();
        expect(builds['a']!, greaterThan(before));
      },
    );

    testWidgets('a hidden card that is undone keeps a fresh, correct build', (
      tester,
    ) async {
      final builds = <String, int>{};
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller, builds: builds));
      controller.swipe(SwipeDirection.right);
      await settle(tester);
      controller.undo();
      await settle(tester);
      expect(find.byKey(cardKey('a')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
