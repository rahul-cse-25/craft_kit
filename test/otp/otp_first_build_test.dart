import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Toggle extends StatefulWidget {
  const _Toggle({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  bool show = false;

  @override
  Widget build(BuildContext context) =>
      show ? widget.builder(context) : const SizedBox.shrink();
}

void main() {
  // The first build after `runApp` or a hot restart runs outside any frame, so
  // the scheduler phase is idle while the tree is being built. A listener
  // above the field that rebuilds on every change must not be dirtied then.
  testWidgets('a listener above the field survives a build outside a frame', (
    tester,
  ) async {
    final controller = OtpCodeController();
    final key = GlobalKey<_ToggleState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _Toggle(
            key: key,
            builder:
                (context) => ListenableBuilder(
                  listenable: controller,
                  builder:
                      (context, _) =>
                          OtpCodeField(controller: controller, length: 4),
                ),
          ),
        ),
      ),
    );

    // Build the field now, synchronously, with the scheduler idle: exactly
    // what mounting the root after a hot restart does.
    // ignore: invalid_use_of_protected_member
    key.currentState!.setState(() => key.currentState!.show = true);
    tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);

    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(OtpCodeField), findsOneWidget);
  });
}
