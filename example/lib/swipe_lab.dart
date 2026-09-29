import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';

import 'swipe_lab_settings.dart';

/// One card of the swipe demo.
class Profile {
  /// Creates a profile.
  const Profile(this.name, this.detail, this.color, this.icon);

  /// Shown large on the card.
  final String name;

  /// Shown under the name.
  final String detail;

  /// The card's color.
  final Color color;

  /// The card's icon.
  final IconData icon;
}

const List<Profile> _base = <Profile>[
  Profile('Aurora', 'Loves night hikes', Color(0xFF6C4DFF), Icons.nightlight),
  Profile('Bolt', 'Coffee, code, repeat', Color(0xFFEF6C00), Icons.bolt),
  Profile('Coral', 'Diver and drummer', Color(0xFF00897B), Icons.waves),
  Profile('Dune', 'Desert photographer', Color(0xFFC0792A), Icons.terrain),
  Profile('Ember', 'Makes hot sauce', Color(0xFFD32F2F), Icons.whatshot),
  Profile('Fable', 'Writes tiny stories', Color(0xFF3949AB), Icons.menu_book),
  Profile('Grove', 'Grows bonsai trees', Color(0xFF2E7D32), Icons.park),
  Profile('Halo', 'Stargazing guide', Color(0xFF8E24AA), Icons.auto_awesome),
];

/// Every deck card is a new instance, so cards are told apart by identity.
List<Profile> makeDeck(int count, {int from = 0}) => <Profile>[
  for (var i = from; i < from + count; i++)
    Profile(
      i < _base.length
          ? _base[i].name
          : '${_base[i % _base.length].name} ${i ~/ _base.length + 1}',
      _base[i % _base.length].detail,
      _base[i % _base.length].color,
      _base[i % _base.length].icon,
    ),
];

const Map<SwipeDirection, String> _labels = <SwipeDirection, String>{
  SwipeDirection.left: 'nope',
  SwipeDirection.right: 'like',
  SwipeDirection.up: 'super',
  SwipeDirection.down: 'skip',
};

const Map<SwipeDirection, Color> _colors = <SwipeDirection, Color>{
  SwipeDirection.left: Colors.red,
  SwipeDirection.right: Colors.green,
  SwipeDirection.up: Colors.blue,
  SwipeDirection.down: Colors.amber,
};

/// The four-direction card demo, driven live by [SwipeLabSettings].
class SwipeDemo extends StatefulWidget {
  /// Creates the demo.
  const SwipeDemo({
    super.key,
    required this.settings,
    required this.controller,
  });

  /// The live settings.
  final SwipeLabSettings settings;

  /// Controls the stack (shared with the control center).
  final SwipeCardController controller;

  @override
  State<SwipeDemo> createState() => _SwipeDemoState();
}

class _SwipeDemoState extends State<SwipeDemo> {
  final Map<SwipeDirection, GlobalKey> _targets = <SwipeDirection, GlobalKey>{
    for (final d in SwipeDirection.values) d: GlobalKey(debugLabel: d.name),
  };
  final Map<SwipeDirection, int> _counts = <SwipeDirection, int>{
    for (final d in SwipeDirection.values) d: 0,
  };

  late List<Profile> _deck;
  int _seenVersion = 0;
  int _serial = 0;
  int _cardBuilds = 0;
  String _last = 'Drag a card, or use the buttons';

  SwipeLabSettings get _s => widget.settings;

  @override
  void initState() {
    super.initState();
    _deck = makeDeck(_s.deckSize);
    _serial = _s.deckSize;
    _seenVersion = _s.deckVersion;
    _s.addListener(_onSettings);
  }

  @override
  void dispose() {
    _s.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (_s.deckVersion == _seenVersion) return;
    _seenVersion = _s.deckVersion;
    setState(() {
      _deck = makeDeck(_s.deckSize);
      _serial = _s.deckSize;
      for (final d in SwipeDirection.values) {
        _counts[d] = 0;
      }
      _last = 'Drag a card, or use the buttons';
    });
    widget.controller.reset();
  }

  Map<SwipeDirection, SwipeBehavior<Profile>> _behaviors() {
    final map = <SwipeDirection, SwipeBehavior<Profile>>{};
    for (final d in SwipeDirection.values) {
      final action = _s.actions[d]!;
      if (action == DirectionAction.off) continue;
      final SwipeGuard<Profile>? guard = _s.refusing.contains(d)
          ? (profile) => !profile.name.startsWith('Coral')
          : null;
      map[d] = switch (action) {
        DirectionAction.dismiss => SwipeBehavior<Profile>.dismiss(guard: guard),
        DirectionAction.consume => SwipeBehavior<Profile>.consume(
          target: SwipeTarget(
            key: _targets[d]!,
            endScale: _s.consumeEndScale,
            arc: _s.consumeArc,
            fade: _s.consumeFade,
            effect: _s.consumeEffect,
            genieLag: _s.genieLag,
          ),
          guard: guard,
        ),
        DirectionAction.springBack => SwipeBehavior<Profile>.springBack(
          guard: guard,
        ),
        DirectionAction.sendToBack => SwipeBehavior<Profile>.sendToBack(
          guard: guard,
        ),
        DirectionAction.undo => SwipeBehavior<Profile>.undo(guard: guard),
        DirectionAction.off => throw StateError('unreachable'),
      };
    }
    return map;
  }

  String _describe(SwipeEvent<Profile> e) =>
      '${e.item.name} · ${_word(e.direction)}';

  /// The word for a direction, which depends on what it does now.
  String _word(SwipeDirection d) {
    if (d == SwipeDirection.down && _s.actions[d] == DirectionAction.undo) {
      return 'back';
    }
    return _labels[d]!;
  }

  void _onSwipe(SwipeEvent<Profile> e) {
    setState(() {
      _last = _describe(e);
      // A trigger never leaves, so it counts at once; others when they land.
      if (e.outcome == SwipeOutcome.springBack ||
          e.outcome == SwipeOutcome.undo) {
        _counts[e.direction] = _counts[e.direction]! + 1;
      }
    });
    _s.log(
      'swipe  ${e.item.name} ${e.direction.name} ${e.outcome.name}'
      '${e.programmatic ? " (button)" : ""}'
      ' v=${e.velocity.distance.round()}px/s  ${e.remaining} left',
    );
  }

  void _onSwipeEnd(SwipeEvent<Profile> e) {
    setState(() => _counts[e.direction] = _counts[e.direction]! + 1);
    _s.log('landed ${e.item.name} (${e.outcome.name})');
  }

  void _more(int remaining) {
    _s.log('needMore: $remaining left, loading 5');
    setState(() {
      _deck = <Profile>[..._deck, ...makeDeck(5, from: _serial)];
      _serial += 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _s,
      builder: (context, _) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: _s.reduceMotion),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            children: <Widget>[
              Expanded(
                child: SwipeCardStack<Profile>(
                  items: _deck,
                  controller: widget.controller,
                  behaviors: _behaviors(),
                  physics: _s.physics,
                  layout: _s.layout,
                  haptics: _s.haptics,
                  enabled: _s.enabled,
                  enableKeyboard: _s.keyboard,
                  historyLimit: _s.historyLimit,
                  needMoreThreshold: _s.needMoreThreshold,
                  preloadCount: _s.preloadCount,
                  overlayBuilder: _s.showStamps ? _stamps : null,
                  onSwipe: _onSwipe,
                  onSwipeEnd: _onSwipeEnd,
                  onUndo: (e) {
                    setState(() => _last = 'undo ${e.item.name}');
                    _s.log('undo   ${e.item.name}');
                  },
                  onEnd: () => _s.log('end: the deck is empty'),
                  onNeedMore: _s.infinite ? _more : null,
                  onPreload: (context, profile, depth) =>
                      _s.log('preload ${profile.name} (depth $depth)'),
                  emptyBuilder: (context) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text('No more cards'),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _s.regenerate,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Start over'),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context, profile, info) {
                    _cardBuilds++;
                    return _ProfileCard(profile: profile);
                  },
                ),
              ),
              const SizedBox(height: 6),
              // Refreshes live with the drag, so the build counter can be
              // watched: it stays put while a card is dragged or animated.
              ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[
                  widget.controller.remaining,
                  widget.controller.progress,
                ]),
                builder: (context, _) => Text(
                  '$_last   |   ${widget.controller.remaining.value} left   |   '
                  '${_counts[SwipeDirection.up]} super   |   card builds: $_cardBuilds',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 6),
              _Actions(
                controller: widget.controller,
                targets: _targets,
                counts: _counts,
                actions: _s.actions,
                rewindStagger: _s.rewindStagger,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Every direction draws from its own progress, so they fade in and out
  /// independently and never flicker across the diagonal.
  Widget _stamps(BuildContext context, SwipeProgress progress) {
    final back = _s.actions[SwipeDirection.down] == DirectionAction.undo;
    if (_s.overlayStyle == OverlayStyle.stamps) {
      return SwipeStampOverlay(
        progress: progress,
        borderRadius: BorderRadius.circular(28),
        stamps: <SwipeStamp>[
          const SwipeStamp(
            direction: SwipeDirection.right,
            label: 'LIKE',
            color: Colors.green,
          ),
          const SwipeStamp(
            direction: SwipeDirection.left,
            label: 'NOPE',
            color: Colors.red,
          ),
          const SwipeStamp(
            direction: SwipeDirection.up,
            label: 'SUPER',
            color: Colors.blue,
          ),
          SwipeStamp(
            direction: SwipeDirection.down,
            label: back ? 'BACK' : 'SKIP',
            color: Colors.amber,
          ),
        ],
      );
    }
    return SwipeIntentOverlay(
      progress: progress,
      borderRadius: BorderRadius.circular(28),
      intents: <SwipeIntent>[
        const SwipeIntent(
          direction: SwipeDirection.right,
          color: Color(0xFF22C55E),
          icon: Icon(Icons.favorite_rounded),
          label: 'Like',
        ),
        const SwipeIntent(
          direction: SwipeDirection.left,
          color: Color(0xFFEF4444),
          icon: Icon(Icons.close_rounded),
          label: 'Nope',
        ),
        const SwipeIntent(
          direction: SwipeDirection.up,
          color: Color(0xFF3B82F6),
          icon: Icon(Icons.star_rounded),
          label: 'Super',
        ),
        SwipeIntent(
          direction: SwipeDirection.down,
          color: const Color(0xFFF59E0B),
          icon: Icon(
            back ? Icons.replay_rounded : Icons.keyboard_double_arrow_down,
          ),
          label: back ? 'Back' : 'Skip',
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            profile.color,
            Color.lerp(profile.color, Colors.black, 0.45)!,
          ],
        ),
        // The edge and shadow keep a card readable against the one behind it.
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(profile.icon, size: 96, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              profile.name,
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              profile.detail,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One button per direction. Each is also the target of its own direction when
/// that direction is set to "consume".
class _Actions extends StatelessWidget {
  const _Actions({
    required this.controller,
    required this.targets,
    required this.counts,
    required this.actions,
    required this.rewindStagger,
  });

  final SwipeCardController controller;
  final Map<SwipeDirection, GlobalKey> targets;
  final Map<SwipeDirection, int> counts;
  final Map<SwipeDirection, DirectionAction> actions;

  /// Pause between cards of a rewind, in milliseconds.
  final int rewindStagger;

  Widget _button(SwipeDirection d, IconData icon, String tooltip, Color color) {
    final enabled = actions[d] != DirectionAction.off;
    return SwipeReaction(
      controller: controller,
      direction: d,
      builder: (context, state, child) => Transform.scale(
        scale: 1 + 0.25 * state.approach + 0.35 * state.arrival,
        child: child,
      ),
      child: Badge(
        label: Text('${counts[d]}'),
        isLabelVisible: counts[d]! > 0,
        child: IconButton.filledTonal(
          key: targets[d],
          tooltip: tooltip,
          color: color,
          onPressed: enabled ? () => controller.swipe(d) : null,
          icon: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _button(SwipeDirection.left, Icons.close, 'Nope', Colors.red),
        _button(
          SwipeDirection.down,
          Icons.arrow_downward,
          actions[SwipeDirection.down] == DirectionAction.undo
              ? 'Back'
              : 'Skip',
          Colors.amber.shade800,
        ),
        ValueListenableBuilder<bool>(
          valueListenable: controller.undoAvailable,
          builder: (context, canUndo, _) => IconButton.outlined(
            tooltip: 'Undo',
            onPressed: canUndo ? controller.undo : null,
            icon: const Icon(Icons.undo),
          ),
        ),
        // Brings every swiped card back, one after another.
        ValueListenableBuilder<bool>(
          valueListenable: controller.undoAvailable,
          builder: (context, canUndo, _) => IconButton.outlined(
            tooltip: 'Rewind all',
            onPressed: canUndo
                ? () => controller.rewind(
                    stagger: Duration(milliseconds: rewindStagger),
                  )
                : null,
            icon: const Icon(Icons.fast_rewind),
          ),
        ),
        _button(SwipeDirection.up, Icons.star, 'Super', Colors.blue),
        _button(SwipeDirection.right, Icons.favorite, 'Like', Colors.green),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Control center
// ---------------------------------------------------------------------------

/// A draggable sheet that exposes every capability of the swipe stack live.
///
/// It is not modal: the cards stay interactive behind it, so a change can be
/// felt straight away.
class SwipeControlCenter extends StatelessWidget {
  /// Creates the control center.
  const SwipeControlCenter({
    super.key,
    required this.settings,
    required this.controller,
    required this.onClose,
  });

  /// The live settings.
  final SwipeLabSettings settings;

  /// The stack's controller, for live readouts.
  final SwipeCardController controller;

  /// Closes the sheet.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.46,
      minChildSize: 0.1,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const <double>[0.1, 0.46, 0.92],
      builder: (context, scroll) => Material(
        elevation: 16,
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => CustomScrollView(
            controller: scroll,
            slivers: <Widget>[
              // Pinned, so Close and Reset all never scroll away. It is part
              // of the scrollable, so dragging it still resizes the sheet.
              SliverPersistentHeader(
                pinned: true,
                delegate: _HeaderDelegate(
                  color: scheme.surfaceContainerHigh,
                  handleColor: scheme.outlineVariant,
                  title: Theme.of(context).textTheme.titleLarge,
                  onReset: settings.resetAll,
                  onClose: onClose,
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  _LiveSection(settings: settings, controller: controller),
                  _DirectionsSection(settings: settings),
                  _PhysicsSection(settings: settings),
                  _SpringsSection(settings: settings),
                  _LayoutSection(settings: settings),
                  _InputSection(settings: settings),
                  _DeckSection(settings: settings, controller: controller),
                  _LogSection(settings: settings),
                  const SizedBox(height: 32),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HeaderDelegate({
    required this.color,
    required this.handleColor,
    required this.title,
    required this.onReset,
    required this.onClose,
  });

  final Color color;
  final Color handleColor;
  final TextStyle? title;
  final VoidCallback onReset;
  final VoidCallback onClose;

  static const double _height = 72;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: color,
      child: Column(
        children: <Widget>[
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Control center',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: title,
                  ),
                ),
                TextButton(onPressed: onReset, child: const Text('Reset all')),
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) => true;
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.decimals = 2,
    this.suffix = '',
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;
  final int decimals;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          SizedBox(width: 128, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '${value.toStringAsFixed(decimals)}$suffix',
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(title),
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: children,
    );
  }
}

class _LiveSection extends StatelessWidget {
  const _LiveSection({required this.settings, required this.controller});

  final SwipeLabSettings settings;
  final SwipeCardController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Live readout',
      initiallyExpanded: true,
      children: <Widget>[
        ValueListenableBuilder<SwipeProgress>(
          valueListenable: controller.progress,
          builder: (context, progress, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: <Widget>[
                for (final d in SwipeDirection.values)
                  Row(
                    children: <Widget>[
                      SizedBox(width: 56, child: Text(d.name)),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress[d],
                          color: _colors[d],
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          progress[d].toStringAsFixed(2),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[
              controller.remaining,
              controller.undoAvailable,
              controller.consuming,
            ]),
            builder: (context, _) {
              final c = controller.consuming.value;
              return Text(
                'remaining ${controller.remaining.value}   ·   '
                'undo ${controller.undoAvailable.value ? "available" : "no"}   ·   '
                'consuming ${c == null ? "none" : "${c.direction.name} ${c.progress.toStringAsFixed(2)}"}',
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DirectionsSection extends StatelessWidget {
  const _DirectionsSection({required this.settings});

  final SwipeLabSettings settings;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Directions: what each one does',
      initiallyExpanded: true,
      children: <Widget>[
        for (final d in SwipeDirection.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 56,
                  child: Text(
                    d.name[0].toUpperCase() + d.name.substring(1),
                    style: TextStyle(
                      color: _colors[d],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: DropdownButton<DirectionAction>(
                    key: ValueKey('action-${d.name}'),
                    isExpanded: true,
                    value: settings.actions[d],
                    items: <DropdownMenuItem<DirectionAction>>[
                      for (final a in DirectionAction.values)
                        DropdownMenuItem<DirectionAction>(
                          value: a,
                          child: Text(a.label),
                        ),
                    ],
                    onChanged: (a) =>
                        settings.change(() => settings.actions[d] = a!),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Refuse Coral (a guard)',
                  child: FilterChip(
                    key: ValueKey('refuse-${d.name}'),
                    label: const Text('guard'),
                    selected: settings.refusing.contains(d),
                    onSelected: (on) => settings.change(() {
                      on
                          ? settings.refusing.add(d)
                          : settings.refusing.remove(d);
                    }),
                  ),
                ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            'Consume flies the card into that direction\'s own button. '
            '"guard" makes the direction refuse the card named Coral, which '
            'then springs back.',
          ),
        ),
        _SliderTile(
          label: 'Consume: end scale',
          value: settings.consumeEndScale,
          min: 0.02,
          max: 0.6,
          onChanged: (v) => settings.change(() => settings.consumeEndScale = v),
        ),
        _SliderTile(
          label: 'Consume: path arc',
          value: settings.consumeArc,
          min: 0,
          max: 0.6,
          onChanged: (v) => settings.change(() => settings.consumeArc = v),
        ),
        _SwitchTile(
          label: 'Consume: fade out on arrival',
          value: settings.consumeFade,
          onChanged: (v) => settings.change(() => settings.consumeFade = v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<SwipeConsumeEffect>(
            key: const ValueKey<String>('consume-effect'),
            showSelectedIcon: false,
            segments: const <ButtonSegment<SwipeConsumeEffect>>[
              ButtonSegment<SwipeConsumeEffect>(
                value: SwipeConsumeEffect.shrink,
                label: Text('shrink'),
              ),
              ButtonSegment<SwipeConsumeEffect>(
                value: SwipeConsumeEffect.genie,
                label: Text('genie'),
              ),
            ],
            selected: <SwipeConsumeEffect>{settings.consumeEffect},
            onSelectionChanged: (s) =>
                settings.change(() => settings.consumeEffect = s.first),
          ),
        ),
        _SliderTile(
          label: 'Genie: funnel length',
          value: settings.genieLag,
          min: 0,
          max: 0.9,
          onChanged: (v) => settings.change(() => settings.genieLag = v),
        ),
      ],
    );
  }
}

class _PhysicsSection extends StatelessWidget {
  const _PhysicsSection({required this.settings});

  final SwipeLabSettings settings;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return _Section(
      title: 'Physics: how it feels',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(value: 'smooth', label: Text('smooth')),
              ButtonSegment<String>(value: 'snappy', label: Text('snappy')),
              ButtonSegment<String>(value: 'bouncy', label: Text('bouncy')),
            ],
            selected: <String>{if (s.preset != 'custom') s.preset},
            onSelectionChanged: (sel) {
              if (sel.isNotEmpty) s.loadPreset(sel.first);
            },
          ),
        ),
        _SliderTile(
          key: const ValueKey('phys-commit'),
          label: 'Commit distance',
          value: s.commitThreshold,
          min: 0.1,
          max: 0.8,
          onChanged: (v) => s.changePhysics(() => s.commitThreshold = v),
        ),
        _SliderTile(
          label: 'Flick projection',
          value: s.projectionTime,
          min: 0,
          max: 0.5,
          suffix: ' s',
          onChanged: (v) => s.changePhysics(() => s.projectionTime = v),
        ),
        _SliderTile(
          label: 'Min. distance',
          value: s.minCommitDistance,
          min: 0,
          max: 60,
          decimals: 0,
          suffix: ' px',
          onChanged: (v) => s.changePhysics(() => s.minCommitDistance = v),
        ),
        _SliderTile(
          label: 'Max tilt',
          value: s.maxAngle,
          min: 0,
          max: 0.7,
          suffix: ' rad',
          onChanged: (v) => s.changePhysics(() => s.maxAngle = v),
        ),
        _SliderTile(
          label: 'Rubber band',
          value: s.rubberBandLimit,
          min: 8,
          max: 160,
          decimals: 0,
          suffix: ' px',
          onChanged: (v) => s.changePhysics(() => s.rubberBandLimit = v),
        ),
        _SliderTile(
          label: 'Button speed',
          value: s.programmaticSpeed,
          min: 300,
          max: 4000,
          decimals: 0,
          suffix: ' px/s',
          onChanged: (v) => s.changePhysics(() => s.programmaticSpeed = v),
        ),
        _SliderTile(
          label: 'Trigger kick',
          value: s.triggerKick,
          min: 100,
          max: 2500,
          decimals: 0,
          suffix: ' px/s',
          onChanged: (v) => s.changePhysics(() => s.triggerKick = v),
        ),
        _SwitchTile(
          label: 'Tilt follows the grab point',
          subtitle: 'Grab the top and it swings one way, the bottom the other',
          value: s.grabTilt,
          onChanged: (v) => s.changePhysics(() => s.grabTilt = v),
        ),
      ],
    );
  }
}

class _SpringsSection extends StatelessWidget {
  const _SpringsSection({required this.settings});

  final SwipeLabSettings settings;

  Widget _spring(
    String name,
    String hint,
    SwipeSpring value,
    ValueChanged<SwipeSpring> set,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            '$name  ·  $hint',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        _SliderTile(
          label: 'Stiffness',
          value: value.stiffness,
          min: 30,
          max: 800,
          decimals: 0,
          onChanged: (v) => set(
            SwipeSpring(
              stiffness: v,
              dampingRatio: value.dampingRatio,
              mass: value.mass,
            ),
          ),
        ),
        _SliderTile(
          label: 'Damping ratio',
          value: value.dampingRatio,
          min: 0.3,
          max: 1.6,
          onChanged: (v) => set(
            SwipeSpring(
              stiffness: value.stiffness,
              dampingRatio: v,
              mass: value.mass,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return _Section(
      title: 'Springs: one per movement',
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Text(
            'Damping 1 = no overshoot; lower bounces; higher is sluggish.',
          ),
        ),
        _spring(
          'Settle',
          'a card returning to the stack',
          s.settle,
          (v) => s.changePhysics(() => s.settle = v),
        ),
        _spring(
          'Fling',
          'a card leaving the screen',
          s.fling,
          (v) => s.changePhysics(() => s.fling = v),
        ),
        _spring(
          'Consume',
          'a card flying into a button',
          s.consume,
          (v) => s.changePhysics(() => s.consume = v),
        ),
        _spring(
          'Undo',
          'a card coming back',
          s.undo,
          (v) => s.changePhysics(() => s.undo = v),
        ),
        _spring(
          'Promote',
          'the cards behind moving up',
          s.promote,
          (v) => s.changePhysics(() => s.promote = v),
        ),
      ],
    );
  }
}

class _LayoutSection extends StatelessWidget {
  const _LayoutSection({required this.settings});

  final SwipeLabSettings settings;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return _Section(
      title: 'Layout: the cards behind',
      children: <Widget>[
        _SliderTile(
          label: 'Visible cards',
          value: s.visibleCards.toDouble(),
          min: 1,
          max: 6,
          divisions: 5,
          decimals: 0,
          onChanged: (v) => s.change(() => s.visibleCards = v.round()),
        ),
        _SliderTile(
          label: 'Peek per card',
          value: s.stackOffset,
          min: 0,
          max: 40,
          decimals: 0,
          suffix: ' px',
          onChanged: (v) => s.change(() => s.stackOffset = v),
        ),
        _SliderTile(
          label: 'Narrower per card',
          value: s.scaleStep,
          min: 0,
          max: 0.15,
          onChanged: (v) => s.change(() => s.scaleStep = v),
        ),
        _SliderTile(
          label: 'Fan (tilt per card)',
          value: s.tilt,
          min: -0.15,
          max: 0.15,
          suffix: ' rad',
          onChanged: (v) => s.change(() => s.tilt = v),
        ),
      ],
    );
  }
}

class _InputSection extends StatelessWidget {
  const _InputSection({required this.settings});

  final SwipeLabSettings settings;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return _Section(
      title: 'Input, feedback and accessibility',
      children: <Widget>[
        _SwitchTile(
          label: 'Touch enabled',
          subtitle: 'Off: only the buttons and the controller move cards',
          value: s.enabled,
          onChanged: (v) => s.change(() => s.enabled = v),
        ),
        _SwitchTile(
          label: 'Arrow keys',
          subtitle: 'Swipe with the keyboard while the stack has focus',
          value: s.keyboard,
          onChanged: (v) => s.change(() => s.keyboard = v),
        ),
        _SwitchTile(
          label: 'Haptic tick at the threshold',
          value: s.hapticThreshold,
          onChanged: (v) => s.change(() => s.hapticThreshold = v),
        ),
        _SwitchTile(
          label: 'Haptic on commit',
          value: s.hapticCommit,
          onChanged: (v) => s.change(() => s.hapticCommit = v),
        ),
        _SwitchTile(
          label: 'Direction stamps',
          subtitle: 'The overlay built from per-direction progress',
          value: s.showStamps,
          onChanged: (v) => s.change(() => s.showStamps = v),
        ),
        if (s.showStamps)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<OverlayStyle>(
              key: const ValueKey<String>('overlay-style'),
              showSelectedIcon: false,
              segments: const <ButtonSegment<OverlayStyle>>[
                ButtonSegment<OverlayStyle>(
                  value: OverlayStyle.stamps,
                  label: Text('stamps'),
                ),
                ButtonSegment<OverlayStyle>(
                  value: OverlayStyle.badge,
                  label: Text('badge'),
                ),
              ],
              selected: <OverlayStyle>{s.overlayStyle},
              onSelectionChanged: (v) =>
                  s.change(() => s.overlayStyle = v.first),
            ),
          ),
        _SwitchTile(
          label: 'Reduce motion',
          subtitle: 'What a user with "remove animations" sees',
          value: s.reduceMotion,
          onChanged: (v) => s.change(() => s.reduceMotion = v),
        ),
      ],
    );
  }
}

class _DeckSection extends StatelessWidget {
  const _DeckSection({required this.settings, required this.controller});

  final SwipeLabSettings settings;
  final SwipeCardController controller;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return _Section(
      title: 'Deck and feeds',
      children: <Widget>[
        _SliderTile(
          label: 'Cards in deck',
          value: s.deckSize.toDouble(),
          min: 2,
          max: 40,
          divisions: 38,
          decimals: 0,
          onChanged: (v) => s.change(() {
            s.deckSize = v.round();
            s.deckVersion++;
          }),
        ),
        _SliderTile(
          label: 'Undo history',
          value: s.historyLimit.toDouble(),
          min: 0,
          max: 50,
          divisions: 50,
          decimals: 0,
          onChanged: (v) => s.change(() => s.historyLimit = v.round()),
        ),
        _SwitchTile(
          label: 'Infinite feed',
          subtitle: 'onNeedMore appends 5 cards when the deck runs low',
          value: s.infinite,
          onChanged: (v) => s.change(() => s.infinite = v),
        ),
        _SliderTile(
          label: 'Load more at',
          value: s.needMoreThreshold.toDouble(),
          min: 0,
          max: 8,
          divisions: 8,
          decimals: 0,
          onChanged: (v) => s.change(() => s.needMoreThreshold = v.round()),
        ),
        _SliderTile(
          label: 'Preload ahead',
          value: s.preloadCount.toDouble(),
          min: 0,
          max: 6,
          divisions: 6,
          decimals: 0,
          onChanged: (v) => s.change(() => s.preloadCount = v.round()),
        ),
        _SliderTile(
          label: 'Rewind pause',
          value: s.rewindStagger.toDouble(),
          min: 0,
          max: 400,
          decimals: 0,
          suffix: ' ms',
          onChanged: (v) => s.change(() => s.rewindStagger = v.round()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ValueListenableBuilder<bool>(
              valueListenable: controller.undoAvailable,
              builder: (context, canUndo, _) => FilledButton.tonalIcon(
                onPressed: canUndo
                    ? () => controller.rewind(
                        stagger: Duration(milliseconds: s.rewindStagger),
                      )
                    : null,
                icon: const Icon(Icons.fast_rewind),
                label: const Text('Rewind all'),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: s.regenerate,
              icon: const Icon(Icons.refresh),
              label: const Text('New deck'),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogSection extends StatelessWidget {
  const _LogSection({required this.settings});

  final SwipeLabSettings settings;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Event log',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ValueListenableBuilder<int>(
            valueListenable: settings.logVersion,
            builder: (context, _, _) => Align(
              alignment: Alignment.centerLeft,
              child: settings.events.isEmpty
                  ? const Text('Swipe a card to see the callbacks fire.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final line in settings.events.take(14))
                          Text(
                            line,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
