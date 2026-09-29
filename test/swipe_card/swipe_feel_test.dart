import 'dart:math' as math;

import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'swipe_test_utils.dart';

/// The card's on-screen rotation in radians (top edge direction).
double angleOf(WidgetTester tester, String item) {
  final f = find.byKey(cardKey(item));
  final v = tester.getTopRight(f) - tester.getTopLeft(f);
  return math.atan2(v.dy, v.dx);
}

void main() {
  group('tilt does not flip when a card is released', () {
    /// Grabs the card at [from], drags it by [delta] and lets go with a real
    /// velocity, returning the angle just before release and each frame after.
    Future<({double before, List<double> after})> flingFrom(
      WidgetTester tester,
      Offset from,
      Offset delta, {
      SwipeCardController? controller,
    }) async {
      final gesture = await tester.startGesture(from);
      const steps = 6;
      for (var i = 1; i <= steps; i++) {
        await gesture.moveBy(
          delta / steps.toDouble(),
          timeStamp: Duration(milliseconds: 16 * i),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      final before = angleOf(tester, 'a');
      await gesture.up();
      final after = <double>[];
      for (var i = 0; i < 40 && isBuilt('a'); i++) {
        await tester.pump(const Duration(milliseconds: 8));
        if (isBuilt('a')) after.add(angleOf(tester, 'a'));
      }
      return (before: before, after: after);
    }

    testWidgets('grabbed at the bottom right and dragged left (your case)', (
      tester,
    ) async {
      await tester.pumpWidget(swipeApp());
      final r = await flingFrom(
        tester,
        const Offset(250, 330),
        const Offset(-120, 0),
      );

      // Grabbed low, the card leans against the finger.
      expect(r.before.abs(), greaterThan(0.02));
      expect(r.after, isNotEmpty);
      // It keeps leaning the same way, and never turns over on release.
      for (final a in r.after) {
        expect(a.sign, r.before.sign, reason: 'angle $a after ${r.before}');
      }
      // And it changes gradually from frame to frame.
      var previous = r.before;
      for (final a in r.after) {
        expect((a - previous).abs(), lessThan(0.06));
        previous = a;
      }
    });

    testWidgets('grabbed at the top left and dragged right', (tester) async {
      await tester.pumpWidget(swipeApp());
      final r = await flingFrom(
        tester,
        const Offset(50, 40),
        const Offset(120, 0),
      );
      expect(r.before.abs(), greaterThan(0.02));
      for (final a in r.after) {
        expect(a.sign, r.before.sign);
      }
    });

    testWidgets('a grab at the top and at the bottom lean opposite ways', (
      tester,
    ) async {
      await tester.pumpWidget(swipeApp());
      final top = await flingFrom(
        tester,
        const Offset(150, 40),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        swipeApp(items: ['a', 'b', 'c'], stackKey: UniqueKey()),
      );
      final bottom = await flingFrom(
        tester,
        const Offset(150, 330),
        const Offset(-120, 0),
      );
      expect(top.before.sign, isNot(bottom.before.sign));
    });

    testWidgets('a spring back keeps the lean it had', (tester) async {
      await tester.pumpWidget(swipeApp());
      final gesture = await tester.startGesture(const Offset(250, 330));
      for (var i = 1; i <= 8; i++) {
        await gesture.moveBy(
          const Offset(-5, 0),
          timeStamp: Duration(milliseconds: 60 * i),
        );
        await tester.pump(const Duration(milliseconds: 60));
      }
      final before = angleOf(tester, 'a');
      expect(before.abs(), greaterThan(0.005));
      await gesture.up();
      var previous = before;
      for (var i = 0; i < 60 && tester.binding.hasScheduledFrame; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        final a = angleOf(tester, 'a');
        // Returning to level: it may cross zero at the very end, but it does
        // not jump.
        expect((a - previous).abs(), lessThan(0.05));
        previous = a;
      }
    });

    testWidgets('undoing a card grabbed low brings it back with that lean', (
      tester,
    ) async {
      final controller = SwipeCardController();
      await tester.pumpWidget(swipeApp(controller: controller));
      final gesture = await tester.startGesture(const Offset(250, 330));
      for (var i = 1; i <= 6; i++) {
        await gesture.moveBy(
          const Offset(-20, 0),
          timeStamp: Duration(milliseconds: 16 * i),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      final leaning = angleOf(tester, 'a');
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 48)); // mid-flight
      final flying = angleOf(tester, 'a');
      expect(flying.sign, leaning.sign);

      controller.undo();
      await tester.pump();
      // It turns back the way it came, without flipping.
      final justUndone = angleOf(tester, 'a');
      expect((justUndone - flying).abs(), lessThan(0.02));
      await settle(tester);
    });
  });
}
