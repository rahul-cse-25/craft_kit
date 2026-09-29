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
      home: const DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: _Bar(),
          body: TabBarView(
            children: <Widget>[_EmailDemo(), _OtpDemo(), _SwipeDemo()],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget implements PreferredSizeWidget {
  const _Bar();

  @override
  Size get preferredSize => const Size.fromHeight(104);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('craft_kit'),
      bottom: const TabBar(
        tabs: <Tab>[
          Tab(text: 'Email'),
          Tab(text: 'OTP'),
          Tab(text: 'Swipe'),
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

class _SwipeDemo extends StatefulWidget {
  const _SwipeDemo();

  @override
  State<_SwipeDemo> createState() => _SwipeDemoState();
}

class _SwipeDemoState extends State<_SwipeDemo> {
  final SwipeCardController _controller = SwipeCardController();
  final List<int> _cards = List<int>.generate(8, (i) => i + 1);
  String _last = 'Swipe a card';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          Expanded(
            child: SwipeCardStack<int>(
              items: _cards,
              controller: _controller,
              onSwipe: (item, index, direction) =>
                  setState(() => _last = 'Card $item swiped ${direction.name}'),
              emptyBuilder: (context) =>
                  const Center(child: Text('No more cards')),
              itemBuilder: (context, item, index) => Card(
                elevation: 4,
                color:
                    Colors.primaries[item % Colors.primaries.length].shade200,
                child: Center(
                  child: Text(
                    '$item',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(_last),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              IconButton.filledTonal(
                onPressed: () => _controller.swipe(SwipeDirection.left),
                icon: const Icon(Icons.close),
              ),
              IconButton.outlined(
                onPressed: _controller.undo,
                icon: const Icon(Icons.undo),
              ),
              IconButton.filledTonal(
                onPressed: () => _controller.swipe(SwipeDirection.right),
                icon: const Icon(Icons.favorite),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
