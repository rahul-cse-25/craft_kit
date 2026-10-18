import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A deck stand-in that counts how often its state is created.
class _Deck extends StatefulWidget {
  const _Deck(this.label);

  final String label;

  static int created = 0;

  @override
  State<_Deck> createState() => _DeckState();
}

class _DeckState extends State<_Deck> {
  @override
  void initState() {
    super.initState();
    _Deck.created++;
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF3366FF),
    child: Center(child: Text(widget.label)),
  );
}

Widget _host({
  required Object deckKey,
  required String label,
  SwipeDeckTransition transition = SwipeDeckTransition.deal,
  bool reduceMotion = false,
  VoidCallback? onSettled,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 600),
      disableAnimations: reduceMotion,
    ),
    child: Center(
      child: SizedBox(
        width: 300,
        height: 400,
        child: SwipeDeckSwitcher(
          deckKey: deckKey,
          transition: transition,
          haptics: false,
          onSettled: onSettled,
          child: _Deck(label),
        ),
      ),
    ),
  ),
);

/// The frozen picture of the leaving deck, if one is on screen.
Finder get _leaving => find.byType(RawImage);

/// Widgets of [type] the switcher wraps around the decks.
Finder _motionInSwitcher(Type type) => find.descendant(
  of: find.byType(SwipeDeckSwitcher),
  matching: find.byType(type),
);

void main() {
  setUp(() => _Deck.created = 0);

  testWidgets('the same key rebuilds in place and keeps state', (tester) async {
    await tester.pumpWidget(_host(deckKey: 'a', label: 'one'));
    await tester.pumpWidget(_host(deckKey: 'a', label: 'two'));
    await tester.pump();

    expect(find.text('two'), findsOneWidget);
    expect(_Deck.created, 1);
    expect(_leaving, findsNothing);
  });

  testWidgets('deal throws a picture of the old deck and lands the new one', (
    tester,
  ) async {
    var settled = 0;
    await tester.pumpWidget(_host(deckKey: 'a', label: 'old'));
    await tester.pumpWidget(
      _host(deckKey: 'b', label: 'new', onSettled: () => settled++),
    );
    await tester.pump(const Duration(milliseconds: 60));

    // The old deck leaves as a picture; the live tree already holds the new.
    expect(_leaving, findsOneWidget);
    expect(find.text('old'), findsNothing);
    expect(find.text('new'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(_leaving, findsNothing);
    expect(find.text('new'), findsOneWidget);
    expect(_Deck.created, 2);
    expect(settled, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flip builds the new deck once and settles upright', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(deckKey: 'a', label: 'old', transition: SwipeDeckTransition.flip),
    );
    await tester.pumpWidget(
      _host(deckKey: 'b', label: 'new', transition: SwipeDeckTransition.flip),
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(_leaving, findsOneWidget);

    await tester.pumpAndSettle();
    expect(_leaving, findsNothing);
    expect(_Deck.created, 2);
    // Settled: the deck is handed back bare, with no turn left on it.
    expect(_motionInSwitcher(Transform), findsNothing);
  });

  testWidgets('none swaps at once', (tester) async {
    var settled = 0;
    await tester.pumpWidget(
      _host(deckKey: 'a', label: 'old', transition: SwipeDeckTransition.none),
    );
    await tester.pumpWidget(
      _host(
        deckKey: 'b',
        label: 'new',
        transition: SwipeDeckTransition.none,
        onSettled: () => settled++,
      ),
    );

    expect(_leaving, findsNothing);
    expect(find.text('new'), findsOneWidget);
    expect(settled, 1);
  });

  testWidgets('reduced motion turns a deal into a short fade', (tester) async {
    await tester.pumpWidget(
      _host(deckKey: 'a', label: 'old', reduceMotion: true),
    );
    await tester.pumpWidget(
      _host(deckKey: 'b', label: 'new', reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 80));

    // Mid-fade: only opacity changes, nothing moves or turns.
    expect(_motionInSwitcher(Opacity), findsWidgets);
    expect(_motionInSwitcher(Transform), findsNothing);

    await tester.pump(const Duration(milliseconds: 120));
    expect(_leaving, findsNothing);
    expect(_motionInSwitcher(Opacity), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a new key mid-transition restarts cleanly', (tester) async {
    await tester.pumpWidget(_host(deckKey: 'a', label: 'one'));
    await tester.pumpWidget(_host(deckKey: 'b', label: 'two'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_host(deckKey: 'c', label: 'three'));
    await tester.pump(const Duration(milliseconds: 30));

    expect(_leaving, findsOneWidget);
    await tester.pumpAndSettle();
    expect(_leaving, findsNothing);
    expect(find.text('three'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing mid-transition leaves nothing running', (
    tester,
  ) async {
    await tester.pumpWidget(_host(deckKey: 'a', label: 'one'));
    await tester.pumpWidget(_host(deckKey: 'b', label: 'two'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
