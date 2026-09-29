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
  final RememberedEmailStore _store = RememberedEmailStore(
    storage: MemoryCraftStorage(),
  );
  final TextEditingController _email = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final Future<void> _loading = _store.load();

  @override
  void dispose() {
    _email.dispose();
    _store.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    final saved = await _store.rememberIfEnabled(_email.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved ? 'Email remembered' : 'Signed in')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              children: <Widget>[
                RememberEmailField(store: _store, controller: _email),
                const SizedBox(height: 16),
                FilledButton(onPressed: _signIn, child: const Text('Sign in')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OtpDemo extends StatefulWidget {
  const _OtpDemo();

  @override
  State<_OtpDemo> createState() => _OtpDemoState();
}

class _OtpDemoState extends State<_OtpDemo> {
  final OtpController _otp = OtpController(length: 6);
  String? _status;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('Type, or long-press the boxes to paste'),
          const SizedBox(height: 16),
          OtpField(
            controller: _otp,
            onCompleted: (code) => setState(() => _status = 'Entered $code'),
            onChanged: (_) {
              if (_status != null && !_otp.isComplete) {
                setState(() => _status = null);
              }
            },
          ),
          const SizedBox(height: 16),
          Text(_status ?? ' '),
          TextButton(
            onPressed: () => _otp.setValue('Your code is 482913'),
            child: const Text('Simulate SMS autofill'),
          ),
          TextButton(onPressed: _otp.clear, child: const Text('Clear')),
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
              overlayBuilder: (context, direction, progress) => Opacity(
                opacity: progress,
                child: Align(
                  alignment: direction == SwipeDirection.right
                      ? Alignment.topLeft
                      : Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      direction == SwipeDirection.right ? 'LIKE' : 'NOPE',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: direction == SwipeDirection.right
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
                ),
              ),
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
