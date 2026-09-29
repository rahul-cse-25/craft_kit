# craft_kit

A growing toolkit of Flutter UI helpers. Each feature is self-contained, has no
third-party dependencies, and is tested.

| Feature | What you get |
|---|---|
| **Remembered emails** | `RememberedEmailStore` (logic) and `RememberEmailField` (widget) with "remember me", suggestions, de-duplication and a size cap. |
| **OTP input** | `OtpController` and `OtpField`: typing, paste, long-press paste, and system autofill, all cleaned to a valid code. |
| **Swipeable cards** | `SwipeCardStack` and `SwipeCardController`: drag, fling, programmatic swipe, undo, overlays. |

## Install

```yaml
dependencies:
  craft_kit: ^0.1.0
```

```dart
import 'package:craft_kit/craft_kit.dart';
```

## Remembered emails

The store is UI-independent and persists through a `CraftStorage` you provide,
so the package does not force a storage plugin on you.

```dart
final store = RememberedEmailStore(storage: MyStorage(), maxEntries: 5);
await store.load();

// In your form:
RememberEmailField(store: store, controller: emailController);

// After a successful sign-in:
await store.rememberIfEnabled(emailController.text);
```

Example `CraftStorage` on top of `shared_preferences`:

```dart
class PrefsStorage implements CraftStorage {
  PrefsStorage(this._prefs);
  final SharedPreferences _prefs;

  @override
  Future<String?> read(String key) async => _prefs.getString(key);
  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
```

> Emails are personal data. If that matters for your app, back `CraftStorage`
> with encrypted storage and offer a way to clear it (`store.clear()`).

## OTP input

```dart
final otp = OtpController(length: 6);

OtpField(
  controller: otp,
  autofocus: true,
  onCompleted: (code) => verify(code),
);
```

Ways to fill the code:

- **Typing**: on the keyboard.
- **Paste**: long-press the boxes to paste the clipboard.
- **System paste and autofill**: the hidden input advertises
  `AutofillHints.oneTimeCode`, so iOS keyboard suggestions and Android
  autofill work.
- **From code**: `otp.setValue(...)`, for example with the result of an SMS
  retrieval plugin.

Any text is cleaned with `otp.extractCode`. `"G-123 456"` and
`"Your code is 123456."` both become `123456`. Use `OtpInputType.alphanumeric`
for codes with letters.

## Swipeable cards

```dart
final controller = SwipeCardController();

SizedBox(
  height: 420,
  child: SwipeCardStack<Profile>(
    items: profiles,
    controller: controller,
    itemBuilder: (context, profile, index) => ProfileCard(profile),
    onSwipe: (profile, index, direction) => handle(profile, direction),
    overlayBuilder: (context, direction, progress) =>
        Opacity(opacity: progress, child: Text(direction.name)),
  ),
);

controller.swipe(SwipeDirection.right); // from a button
controller.undo();
```

Options: `allowedDirections`, `threshold`, `visibleCards`, `maxAngle`,
`duration`, `emptyBuilder`, `onEnd`.

## Example

A runnable demo of every feature is in [`example/`](example).

## Contributing

Issues and pull requests are welcome. Run `flutter analyze` and `flutter test`
before sending a change.

## License

MIT, see [LICENSE](LICENSE).
