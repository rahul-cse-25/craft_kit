import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

void main() => runApp(const DemoApp());

/// A small page to try craft_kit's swipe cards in the browser before adding
/// the package. Everything here is public API; nothing is demo-only.
class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'craft_kit: swipe cards',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF7C3AED),
        scaffoldBackgroundColor: const Color(0xFF0E0E12),
      ),
      home: const DemoPage(),
    );
  }
}

class _Card {
  const _Card(this.title, this.subtitle, this.icon, this.a, this.b);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color a;
  final Color b;
}

const List<_Card> _cards = <_Card>[
  _Card(
    'Aurora',
    'Spring physics',
    Icons.waves_rounded,
    Color(0xFF7C3AED),
    Color(0xFF312E81),
  ),
  _Card(
    'Ember',
    'Per-direction behaviors',
    Icons.local_fire_department_rounded,
    Color(0xFFF97316),
    Color(0xFF9A3412),
  ),
  _Card(
    'Tide',
    'Undo and rewind',
    Icons.undo_rounded,
    Color(0xFF06B6D4),
    Color(0xFF155E75),
  ),
  _Card(
    'Moss',
    'Genie into any button',
    Icons.auto_awesome_rounded,
    Color(0xFF22C55E),
    Color(0xFF166534),
  ),
  _Card(
    'Rose',
    'Any card, any layout',
    Icons.dashboard_customize_rounded,
    Color(0xFFEC4899),
    Color(0xFF9D174D),
  ),
  _Card(
    'Slate',
    'No dependencies',
    Icons.inventory_2_rounded,
    Color(0xFF64748B),
    Color(0xFF1E293B),
  ),
  _Card(
    'Gold',
    'Accessible and keyboard ready',
    Icons.accessibility_new_rounded,
    Color(0xFFEAB308),
    Color(0xFF854D0E),
  ),
  _Card(
    'Sky',
    'Smooth on low-end devices',
    Icons.speed_rounded,
    Color(0xFF3B82F6),
    Color(0xFF1E40AF),
  ),
];

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final SwipeCardController _controller = SwipeCardController();
  final GlobalKey _likeKey = GlobalKey();
  bool _genie = true;
  bool _badge = true;
  String _last = 'Drag a card, or use the buttons';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String text) => setState(() => _last = text);

  Map<SwipeDirection, SwipeBehavior<_Card>>
  get _behaviors => <SwipeDirection, SwipeBehavior<_Card>>{
    SwipeDirection.right: SwipeBehavior<_Card>.consume(
      target: SwipeTarget(
        key: _likeKey,
        effect: _genie ? SwipeConsumeEffect.genie : SwipeConsumeEffect.shrink,
      ),
      onCommit: (e) => _say('Liked ${e.item.title}'),
    ),
    SwipeDirection.left: SwipeBehavior<_Card>.dismiss(
      onCommit: (e) => _say('Passed ${e.item.title}'),
    ),
    SwipeDirection.up: SwipeBehavior<_Card>.springBack(
      onCommit: (e) => _say('Super like for ${e.item.title}: the card stays'),
    ),
    SwipeDirection.down: SwipeBehavior<_Card>.undo(),
  };

  Widget _overlay(BuildContext context, SwipeProgress progress) {
    final radius = BorderRadius.circular(28);
    if (_badge) {
      return SwipeIntentOverlay(
        progress: progress,
        borderRadius: radius,
        intents: const <SwipeIntent>[
          SwipeIntent(
            direction: SwipeDirection.right,
            color: Color(0xFF22C55E),
            icon: Icon(Icons.favorite_rounded),
            label: 'Like',
          ),
          SwipeIntent(
            direction: SwipeDirection.left,
            color: Color(0xFFEF4444),
            icon: Icon(Icons.close_rounded),
            label: 'Pass',
          ),
          SwipeIntent(
            direction: SwipeDirection.up,
            color: Color(0xFF3B82F6),
            icon: Icon(Icons.star_rounded),
            label: 'Super',
          ),
          SwipeIntent(
            direction: SwipeDirection.down,
            color: Color(0xFFF59E0B),
            icon: Icon(Icons.replay_rounded),
            label: 'Back',
          ),
        ],
      );
    }
    return SwipeStampOverlay(
      progress: progress,
      borderRadius: radius,
      stamps: const <SwipeStamp>[
        SwipeStamp(
          direction: SwipeDirection.right,
          label: 'LIKE',
          color: Color(0xFF22C55E),
        ),
        SwipeStamp(
          direction: SwipeDirection.left,
          label: 'PASS',
          color: Color(0xFFEF4444),
        ),
        SwipeStamp(
          direction: SwipeDirection.up,
          label: 'SUPER',
          color: Color(0xFF3B82F6),
        ),
        SwipeStamp(
          direction: SwipeDirection.down,
          label: 'BACK',
          color: Color(0xFFF59E0B),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: <Widget>[
                  _Header(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SwipeCardStack<_Card>(
                      items: _cards,
                      controller: _controller,
                      itemKey: (c) => ValueKey<String>(c.title),
                      behaviors: _behaviors,
                      overlayBuilder: _overlay,
                      onUndo: (e) => _say('Back to ${e.item.title}'),
                      emptyBuilder:
                          (context) => Center(
                            child: FilledButton.icon(
                              onPressed: _controller.rewind,
                              icon: const Icon(Icons.replay_rounded),
                              label: const Text('Rewind all cards'),
                            ),
                          ),
                      itemBuilder:
                          (context, card, info) => _CardFace(card: card),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Actions(controller: _controller, likeKey: _likeKey),
                  const SizedBox(height: 10),
                  Text(
                    _last,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  _Options(
                    genie: _genie,
                    badge: _badge,
                    onGenie: (v) => setState(() => _genie = v),
                    onBadge: (v) => setState(() => _badge = v),
                  ),
                  const SizedBox(height: 10),
                  const _Install(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'craft_kit',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(
          onPressed:
              () => web.window.open(
                'https://pub.dev/packages/craft_kit',
                '_blank',
              ),
          child: const Text('pub.dev'),
        ),
        TextButton(
          onPressed:
              () => web.window.open(
                'https://github.com/rahul-cse-25/craft_kit',
                '_blank',
              ),
          child: const Text('GitHub'),
        ),
      ],
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card});

  final _Card card;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[card.a, card.b],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(card.icon, size: 96, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              card.title,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.controller, required this.likeKey});

  final SwipeCardController controller;
  final GlobalKey likeKey;

  @override
  Widget build(BuildContext context) {
    Widget button(
      IconData icon,
      String tip,
      VoidCallback onTap, {
      Color? color,
      double size = 52,
      Key? key,
    }) {
      return Tooltip(
        message: tip,
        child: Material(
          key: key,
          color: color ?? Colors.white12,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: Colors.white, size: size * 0.46),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        button(Icons.fast_rewind_rounded, 'Rewind all', controller.rewind),
        const SizedBox(width: 12),
        button(
          Icons.close_rounded,
          'Pass',
          () => controller.swipe(SwipeDirection.left),
          color: const Color(0xFFEF4444),
        ),
        const SizedBox(width: 12),
        button(Icons.undo_rounded, 'Undo', controller.undo),
        const SizedBox(width: 12),
        button(
          Icons.star_rounded,
          'Super',
          () => controller.swipe(SwipeDirection.up),
          color: const Color(0xFF3B82F6),
        ),
        const SizedBox(width: 12),
        button(
          Icons.favorite_rounded,
          'Like',
          () => controller.swipe(SwipeDirection.right),
          color: const Color(0xFF22C55E),
          size: 60,
          key: likeKey,
        ),
      ],
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({
    required this.genie,
    required this.badge,
    required this.onGenie,
    required this.onBadge,
  });

  final bool genie;
  final bool badge;
  final ValueChanged<bool> onGenie;
  final ValueChanged<bool> onBadge;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        FilterChip(
          label: const Text('Genie effect'),
          selected: genie,
          onSelected: onGenie,
        ),
        FilterChip(
          label: const Text('Badge overlay'),
          selected: badge,
          onSelected: onBadge,
        ),
      ],
    );
  }
}

class _Install extends StatelessWidget {
  const _Install();

  static const String _command = 'flutter pub add craft_kit';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Clipboard.setData(const ClipboardData(text: _command));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text('Copied'),
                duration: Duration(seconds: 1),
              ),
            );
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '\$ $_command',
                style: TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
              SizedBox(width: 10),
              Icon(Icons.copy_rounded, size: 16, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
