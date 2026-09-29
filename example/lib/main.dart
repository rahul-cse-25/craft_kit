import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/material.dart';

import 'swipe_lab.dart';
import 'swipe_lab_settings.dart';

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
  static const int _swipeTab = 2;

  final SwipeLabSettings _settings = SwipeLabSettings();
  final SwipeCardController _controller = SwipeCardController();

  int _index = 0;
  bool _panelOpen = false;

  @override
  void dispose() {
    _controller.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSwipeTab = _index == _swipeTab;
    final pages = <Widget>[
      const _EmailDemo(),
      const _OtpDemo(),
      SwipeDemo(settings: _settings, controller: _controller),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('craft_kit'),
        actions: <Widget>[
          if (onSwipeTab)
            IconButton(
              tooltip: 'Control center',
              isSelected: _panelOpen,
              icon: const Icon(Icons.tune),
              selectedIcon: const Icon(Icons.tune),
              onPressed: () => setState(() => _panelOpen = !_panelOpen),
            ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          IndexedStack(
            index: _index,
            children: <Widget>[
              for (var i = 0; i < pages.length; i++)
                // Hidden pages keep their state but stop ticking animations.
                TickerMode(enabled: i == _index, child: pages[i]),
            ],
          ),
          if (onSwipeTab && _panelOpen)
            Positioned.fill(
              child: SwipeControlCenter(
                settings: _settings,
                controller: _controller,
                onClose: () => setState(() => _panelOpen = false),
              ),
            ),
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
