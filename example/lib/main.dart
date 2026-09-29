import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';

void main() => runApp(const CraftKitExample());

/// Demo app showing every craft_kit feature.
class CraftKitExample extends StatelessWidget {
  /// Creates the demo app.
  const CraftKitExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'craft_kit',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _Home(),
    );
  }
}

/// Switches demos with a bottom bar and an [IndexedStack].
///
/// A `TabBarView` would put every demo inside a horizontal `PageView`, which
/// wins the gesture arena against the card stack's horizontal drag, so left
/// and right swipes would never reach the cards. An [IndexedStack] has no
/// gestures of its own, and it also keeps each demo's state while hidden.
class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  static const List<Widget> _pages = <Widget>[
    _EmailDemo(),
    _OtpDemo(),
    _SwipeDemo(),
  ];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('craft_kit')),
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          for (var i = 0; i < _pages.length; i++)
            // Hidden pages keep their state but stop ticking animations.
            TickerMode(enabled: i == _index, child: _pages[i]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.alternate_email),
            label: 'Email',
          ),
          NavigationDestination(icon: Icon(Icons.password), label: 'OTP'),
          NavigationDestination(icon: Icon(Icons.style), label: 'Swipe'),
        ],
      ),
    );
  }
}

class _EmailDemo extends StatefulWidget {
  const _EmailDemo();

  @override
  State<_EmailDemo> createState() => _EmailDemoState();
}

class _EmailDemoState extends State<_EmailDemo> {
  // Swap MemoryCraftStorage for your own CraftStorage to persist for real.
  final RememberedEmailStore _store = StorageRememberedEmailStore(
    MemoryCraftStorage(),
  );
  late final EmailFieldController _email = EmailFieldController(store: _store);
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _seed();
  }

  Future<void> _seed() async {
    await _store.rememberEmail('anna@gmail.com');
    await _store.rememberEmail('anna.work@acme.io');
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    await _email.rememberCurrentEmail();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Remembered ${_email.email}')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: Column(
          children: <Widget>[
            const Text('Type "an", or "you@gm" to see suggestions'),
            const SizedBox(height: 16),
            RememberedEmailField(controller: _email),
            FilledButton(onPressed: _signIn, child: const Text('Sign in')),
          ],
        ),
      ),
    );
  }
}

class _OtpDemo extends StatefulWidget {
  const _OtpDemo();

  @override
  State<_OtpDemo> createState() => _OtpDemoState();
}

class _OtpDemoState extends State<_OtpDemo> {
  final OtpCodeController _otp = OtpCodeController();
  String _status = 'Type or paste a 6-digit code';

  @override
  void initState() {
    super.initState();
    _otp.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    setState(() => _status = 'Verifying $code...');
    _otp.beginProcessing();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    if (code == '123456') {
      _otp.showSuccess();
      setState(() => _status = 'Verified');
    } else {
      _otp.showFailure(keepCode: false);
      setState(() => _status = 'Wrong code. Try 123456');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          OtpCodeField(
            controller: _otp,
            autoFocus: false,
            onCompleted: _verify,
          ),
          const SizedBox(height: 24),
          Text(_status),
          const SizedBox(height: 8),
          Text('phase: ${_otp.phase.name}'),
          Wrap(
            spacing: 8,
            children: <Widget>[
              TextButton(
                onPressed: () => _otp.setCode('Your code is 482913'),
                child: const Text('Simulate SMS autofill'),
              ),
              TextButton(onPressed: _otp.clear, child: const Text('Clear')),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Swipe demo
// ---------------------------------------------------------------------------

/// One card of the swipe demo.
class _Profile {
  const _Profile(this.name, this.detail, this.color, this.icon);

  final String name;
  final String detail;
  final Color color;
  final IconData icon;
}

const List<_Profile> _profiles = <_Profile>[
  _Profile('Aurora', 'Loves night hikes', Color(0xFF6C4DFF), Icons.nightlight),
  _Profile('Bolt', 'Coffee, code, repeat', Color(0xFFEF6C00), Icons.bolt),
  _Profile('Coral', 'Diver and drummer', Color(0xFF00897B), Icons.waves),
  _Profile('Dune', 'Desert photographer', Color(0xFFC0792A), Icons.terrain),
  _Profile('Ember', 'Makes hot sauce', Color(0xFFD32F2F), Icons.whatshot),
  _Profile('Fable', 'Writes tiny stories', Color(0xFF3949AB), Icons.menu_book),
  _Profile('Grove', 'Grows bonsai trees', Color(0xFF2E7D32), Icons.park),
  _Profile('Halo', 'Stargazing guide', Color(0xFF8E24AA), Icons.auto_awesome),
];

const Map<String, SwipePhysics> _presets = <String, SwipePhysics>{
  'smooth': SwipePhysics.smooth,
  'snappy': SwipePhysics.snappy,
  'bouncy': SwipePhysics.bouncy,
};

class _SwipeDemo extends StatefulWidget {
  const _SwipeDemo();

  @override
  State<_SwipeDemo> createState() => _SwipeDemoState();
}

class _SwipeDemoState extends State<_SwipeDemo> {
  final SwipeCardController _controller = SwipeCardController();
  final GlobalKey _likeKey = GlobalKey(debugLabel: 'like button');

  List<_Profile> _deck = List<_Profile>.of(_profiles);
  String _preset = 'smooth';
  bool _fan = false;
  String _last = 'Drag a card, or use the buttons';
  int _liked = 0;
  int _supers = 0;
  int _cardBuilds = 0;

  // What each direction does. Right is consumed by the like button, up runs a
  // task and springs back, down sends the card to the end of the deck.
  late final Map<SwipeDirection, SwipeBehavior<_Profile>> _behaviors =
      <SwipeDirection, SwipeBehavior<_Profile>>{
        SwipeDirection.left: SwipeBehavior<_Profile>.dismiss(),
        SwipeDirection.right: SwipeBehavior<_Profile>.consume(
          target: SwipeTarget(key: _likeKey),
          onArrive: (profile) => setState(() => _liked++),
        ),
        SwipeDirection.up: SwipeBehavior<_Profile>.springBack(
          onCommit: (event) => setState(() => _supers++),
        ),
        SwipeDirection.down: SwipeBehavior<_Profile>.sendToBack(),
      };

  static const Map<SwipeDirection, String> _labels = <SwipeDirection, String>{
    SwipeDirection.left: 'nope',
    SwipeDirection.right: 'like',
    SwipeDirection.up: 'super',
    SwipeDirection.down: 'skip',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _deck = List<_Profile>.of(_profiles);
      _liked = 0;
      _supers = 0;
      _last = 'Drag a card, or use the buttons';
    });
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<String>>[
                    for (final name in _presets.keys)
                      ButtonSegment<String>(value: name, label: Text(name)),
                  ],
                  selected: <String>{_preset},
                  onSelectionChanged: (s) => setState(() => _preset = s.first),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('fan'),
                selected: _fan,
                onSelected: (v) => setState(() => _fan = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SwipeCardStack<_Profile>(
              items: _deck,
              controller: _controller,
              behaviors: _behaviors,
              physics: _presets[_preset]!,
              layout: CascadeLayout(tilt: _fan ? 0.05 : 0),
              overlayBuilder: _stamps,
              onSwipe: (event) => setState(() {
                _last = '${event.item.name} · ${_labels[event.direction]}';
              }),
              onPreload: (context, profile, depth) {
                // A real app would precache the profile image here.
              },
              emptyBuilder: (context) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('No more cards'),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _reset,
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
          // Refreshes live with the drag, so the build counter can be watched:
          // it stays put while a card is dragged or animated.
          ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[
              _controller.remaining,
              _controller.progress,
            ]),
            builder: (context, _) => Text(
              '$_last   |   ${_controller.remaining.value} left   |   '
              '$_supers super   |   card builds: $_cardBuilds',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 6),
          _Actions(controller: _controller, likeKey: _likeKey, liked: _liked),
        ],
      ),
    );
  }

  /// Every direction draws its own stamp from its own progress, so they fade
  /// in and out independently and never flicker across the diagonal.
  Widget _stamps(BuildContext context, SwipeProgress progress) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _Stamp('LIKE', Colors.green, Alignment.topLeft, progress.right, -0.25),
        _Stamp('NOPE', Colors.red, Alignment.topRight, progress.left, 0.25),
        _Stamp('SUPER', Colors.blue, Alignment.bottomCenter, progress.up, 0),
        _Stamp('SKIP', Colors.amber, Alignment.topCenter, progress.down, 0),
      ],
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp(this.label, this.color, this.alignment, this.value, this.angle);

  final String label;
  final Color color;
  final Alignment alignment;
  final double value;
  final double angle;

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return const SizedBox.shrink();
    return Opacity(
      opacity: value,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color, width: 4),
        ),
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Transform.rotate(
              angle: angle,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final _Profile profile;

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

class _Actions extends StatelessWidget {
  const _Actions({
    required this.controller,
    required this.likeKey,
    required this.liked,
  });

  final SwipeCardController controller;
  final GlobalKey likeKey;
  final int liked;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton.filledTonal(
          tooltip: 'Nope',
          color: Colors.red,
          onPressed: () => controller.swipe(SwipeDirection.left),
          icon: const Icon(Icons.close),
        ),
        IconButton.filledTonal(
          tooltip: 'Skip',
          color: Colors.amber.shade800,
          onPressed: () => controller.swipe(SwipeDirection.down),
          icon: const Icon(Icons.arrow_downward),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: controller.undoAvailable,
          builder: (context, canUndo, _) => IconButton.outlined(
            tooltip: 'Undo',
            onPressed: canUndo ? controller.undo : null,
            icon: const Icon(Icons.undo),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Super',
          color: Colors.blue,
          onPressed: () => controller.swipe(SwipeDirection.up),
          icon: const Icon(Icons.star),
        ),
        // The like button is where a right swipe is consumed. It swells as a
        // card approaches and pulses when one arrives.
        SwipeReaction(
          controller: controller,
          direction: SwipeDirection.right,
          builder: (context, state, child) => Transform.scale(
            scale: 1 + 0.25 * state.approach + 0.35 * state.arrival,
            child: child,
          ),
          child: Badge(
            label: Text('$liked'),
            isLabelVisible: liked > 0,
            child: IconButton.filledTonal(
              key: likeKey,
              tooltip: 'Like',
              color: Colors.green,
              onPressed: () => controller.swipe(SwipeDirection.right),
              icon: const Icon(Icons.favorite),
            ),
          ),
        ),
      ],
    );
  }
}
