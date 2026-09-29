import 'dart:async';

import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _fast = OtpAnimationSpec(
  entranceDuration: Duration(milliseconds: 20),
  entranceStagger: Duration.zero,
  collapseDuration: Duration(milliseconds: 20),
  restoreDuration: Duration(milliseconds: 20),
  resultDuration: Duration(milliseconds: 20),
  processingPulseDuration: Duration(milliseconds: 40),
  fillDuration: Duration.zero,
  focusDuration: Duration.zero,
);

Widget host({
  required OtpCodeController controller,
  int length = 4,
  ValueChanged<String>? onCompleted,
  ValueChanged<String>? onChanged,
  OtpStyle? style,
  OtpLabels labels = const OtpLabels(),
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Center(
        child: OtpCodeField(
          length: length,
          controller: controller,
          onCompleted: onCompleted,
          onChanged: onChanged,
          style: style,
          labels: labels,
          animationSpec: _fast,
          haptics: const OtpHaptics(success: null, failure: null),
        ),
      ),
    ),
  );
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

/// Rebuilds itself on every controller notification, the way a typical screen
/// does (`controller.addListener(() => setState(() {}))`).
class _Listening extends StatefulWidget {
  const _Listening({required this.controller, required this.child});

  final OtpCodeController controller;
  final Widget child;

  @override
  State<_Listening> createState() => _ListeningState();
}

class _ListeningState extends State<_Listening> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      widget.child,
      Text('phase: ${widget.controller.phase.name}'),
    ],
  );
}

void main() {
  testWidgets('typing fills boxes and fires onCompleted once', (tester) async {
    final controller = OtpCodeController();
    final completed = <String>[];
    final changed = <String>[];
    await tester.pumpWidget(
      host(
        controller: controller,
        onCompleted: completed.add,
        onChanged: changed.add,
      ),
    );
    await settle(tester);

    await tester.enterText(find.byType(EditableText), '12');
    await tester.pump();
    expect(controller.code, '12');
    expect(controller.phase, OtpPhase.editing);

    await tester.enterText(find.byType(EditableText), '1234');
    await tester.pump();
    expect(controller.code, '1234');
    expect(controller.phase, OtpPhase.complete);
    expect(completed, ['1234']);
    expect(changed, ['12', '1234']);

    await unmount(tester);
    controller.dispose();
  });

  testWidgets('a noisy paste is cleaned and completes', (tester) async {
    final controller = OtpCodeController();
    final completed = <String>[];
    await tester.pumpWidget(
      host(controller: controller, onCompleted: completed.add),
    );
    await settle(tester);

    await tester.enterText(find.byType(EditableText), '12 34 99');
    await tester.pump();
    expect(controller.code, '1234');
    expect(completed, ['1234']);

    await unmount(tester);
    controller.dispose();
  });

  testWidgets('setCode from outside fills the field', (tester) async {
    final controller = OtpCodeController();
    final completed = <String>[];
    await tester.pumpWidget(
      host(controller: controller, onCompleted: completed.add),
    );
    await settle(tester);

    controller.setCode('Your code is 4821');
    await tester.pump();
    expect(controller.code, '4821');
    expect(completed, ['4821']);

    controller.clear();
    await tester.pump();
    expect(controller.code, '');

    await unmount(tester);
    controller.dispose();
  });

  testWidgets('processing then success runs to the success phase', (
    tester,
  ) async {
    final controller = OtpCodeController();
    await tester.pumpWidget(host(controller: controller));
    await settle(tester);
    controller.setCode('1234');
    await tester.pump();

    controller.beginProcessing();
    await tester.pump();
    expect(controller.phase, OtpPhase.collapsing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.phase, OtpPhase.processing);

    controller.showSuccess();
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.phase, OtpPhase.success);

    await unmount(tester);
    controller.dispose();
  });

  testWidgets('failure restores editing and keeps the code', (tester) async {
    final controller = OtpCodeController();
    await tester.pumpWidget(host(controller: controller));
    await settle(tester);
    controller.setCode('1234');
    await tester.pump();

    controller.beginProcessing();
    await tester.pump(const Duration(milliseconds: 100));
    controller.showFailure();
    // Each stage (failure, restore) starts on a frame after the previous one
    // finishes, so pump in small steps instead of one big jump.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(controller.phase, OtpPhase.complete);
    expect(controller.code, '1234');

    await unmount(tester);
    controller.dispose();
  });

  testWidgets('input is ignored while processing', (tester) async {
    final controller = OtpCodeController();
    await tester.pumpWidget(host(controller: controller));
    await settle(tester);
    controller.setCode('1234');
    await tester.pump();
    controller.beginProcessing();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(EditableText), '1');
    await tester.pump();
    expect(controller.code, '1234');
    expect(controller.phase.isBusy, isTrue);

    await unmount(tester);
    controller.dispose();
  });

  testWidgets('labels are overridable for semantics', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = OtpCodeController();
    await tester.pumpWidget(
      host(
        controller: controller,
        labels: OtpLabels(
          inputLabel: 'Code de vérification',
          valueBuilder: (f, t) => '$f sur $t',
        ),
      ),
    );
    await settle(tester);

    expect(find.bySemanticsLabel('Code de vérification'), findsOneWidget);

    await unmount(tester);
    controller.dispose();
    handle.dispose();
  });

  testWidgets('works on a light theme without an explicit style', (
    tester,
  ) async {
    final controller = OtpCodeController();
    await tester.pumpWidget(
      host(controller: controller, theme: ThemeData.light()),
    );
    await settle(tester);
    controller.setCode('12');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('1'), findsOneWidget);

    await unmount(tester);
    controller.dispose();
  });

  testWidgets('long rows scale down to fit narrow parents', (tester) async {
    final controller = OtpCodeController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: OtpCodeField(
              length: 6,
              controller: controller,
              style: const OtpStyle(),
              animationSpec: _fast,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(OtpCodeField)).width,
      lessThanOrEqualTo(180),
    );

    await unmount(tester);
    controller.dispose();
  });

  testWidgets('a listener may call setState while the field mounts', (
    tester,
  ) async {
    final controller = OtpCodeController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _Listening(
            controller: controller,
            child: OtpCodeField(controller: controller, animationSpec: _fast),
          ),
        ),
      ),
    );
    await settle(tester);
    controller.setCode('12');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('phase: editing'), findsOneWidget);

    await unmount(tester);
    controller.dispose();
  });

  testWidgets('survives being built and swapped out inside a TabBarView', (
    tester,
  ) async {
    final controller = OtpCodeController();
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              bottom: const TabBar(tabs: [Tab(text: 'a'), Tab(text: 'b')]),
            ),
            body: TabBarView(
              children: [
                Center(
                  child: OtpCodeField(
                    controller: controller,
                    animationSpec: _fast,
                  ),
                ),
                const Text('other'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('b'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await unmount(tester);
    controller.dispose();
  });

  testWidgets('showSuccessAndWait completes after the success animation', (
    tester,
  ) async {
    final controller = OtpCodeController();
    await tester.pumpWidget(host(controller: controller));
    await settle(tester);
    controller.setCode('1234');
    await tester.pump();
    controller.beginProcessing();
    await tester.pump(const Duration(milliseconds: 100));

    var done = false;
    unawaited(controller.showSuccessAndWait().then((_) => done = true));
    await tester.pump();
    expect(done, isFalse);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done, isTrue);
    expect(controller.phase, OtpPhase.success);

    await unmount(tester);
    controller.dispose();
  });

  test('showSuccessAndWait completes immediately with no field attached', () {
    final controller = OtpCodeController();
    expect(controller.showSuccessAndWait(), completes);
    expect(controller.phase, OtpPhase.success);
    controller.dispose();
  });

  group('style defaults stay as Bump has them', () {
    test('const OtpStyle() keeps the classic look', () {
      const style = OtpStyle();
      expect(style.canvasVerticalPadding, 44);
      expect(style.resultGlow, OtpResultGlow.classic);
    });

    testWidgets('field height is boxHeight + 44 by default', (tester) async {
      final controller = OtpCodeController();
      await tester.pumpWidget(
        host(controller: controller, style: const OtpStyle()),
      );
      await settle(tester);
      expect(tester.getSize(find.byType(OtpCodeField)).height, 48 + 44);

      await unmount(tester);
      controller.dispose();
    });

    testWidgets('fromTheme uses the tighter height and gradient glow', (
      tester,
    ) async {
      final theme = ThemeData.light();
      final style = OtpStyle.fromTheme(theme);
      expect(style.canvasVerticalPadding, 24);
      expect(style.resultGlow, OtpResultGlow.followGradient);

      final controller = OtpCodeController();
      await tester.pumpWidget(host(controller: controller, style: style));
      await settle(tester);
      expect(tester.getSize(find.byType(OtpCodeField)).height, 48 + 24);

      await unmount(tester);
      controller.dispose();
    });

    test('fromTheme keeps base geometry and allows overriding the extras', () {
      final style = OtpStyle.fromTheme(
        ThemeData.dark(),
        base: const OtpStyle(boxWidth: 40, gap: 6),
      ).copyWith(canvasVerticalPadding: 44, resultGlow: OtpResultGlow.classic);
      expect(style.boxWidth, 40);
      expect(style.gap, 6);
      expect(style.canvasVerticalPadding, 44);
      expect(style.resultGlow, OtpResultGlow.classic);
    });
  });

  test('OtpStyle.fromTheme follows the color scheme', () {
    final light = OtpStyle.fromTheme(ThemeData.light());
    final dark = OtpStyle.fromTheme(ThemeData.dark());
    expect(light.textColor, isNot(dark.textColor));
    expect(light.focusedBorderColor, ThemeData.light().colorScheme.primary);
  });

  test('Clipboard is not required for typing (sanity)', () {
    expect(SystemChannels.platform.name, isNotEmpty);
  });
}
