# craft_kit

Flutter UI helpers that feel good to use: a **swipeable card stack** with spring
physics, an **OTP input**, and **remembered-email suggestions**. No third-party
dependencies, fully tested, and each part works on its own.

## See it in action

### Swipeable cards

<p align="center">
  <img src="https://raw.githubusercontent.com/rahul-cse-25/craft_kit/main/screenshots/swipe_overview.gif" width="300" alt="Dragging a craft_kit card stack in four directions">
  <img src="https://raw.githubusercontent.com/rahul-cse-25/craft_kit/main/screenshots/swipe_genie.gif" width="300" alt="A craft_kit card pouring into a button with the Dock-style genie effect">
</p>

<p align="center">
  <em>Direction-aware overlays, spring motion, consume targets, and reversible actions.</em>
</p>

### OTP and remembered email

<p align="center">
  <img src="https://raw.githubusercontent.com/rahul-cse-25/craft_kit/main/screenshots/otp.gif" width="280" alt="craft_kit OTP input moving through editing, processing, success, and failure states">
  <img src="https://raw.githubusercontent.com/rahul-cse-25/craft_kit/main/screenshots/email.gif" width="280" alt="craft_kit remembered-email field showing ranked email suggestions">
</p>

<p align="center">
  <em>A complete OTP lifecycle and useful email suggestions, with replaceable UI layers.</em>
</p>

## Why craft_kit

* **Swipe cards that do more than dismiss.** Give every direction its own
  behavior: fly away, pour into a button (Dock-style genie), run a task and
  spring back, go to the back of the deck, or bring the previous card back.
* **Buttery by construction.** Every move is a spring that starts from the
  card's current position and velocity, so nothing jumps and a card can be
  caught mid-flight. Cards are built once and moved with transforms only, and
  nothing ticks while idle.
* **Yours to style.** Any card, any stack look, any drag overlay. Ready-made
  overlays are included.
* **Undo, rewind, jump.** Bring cards back, one or all, or jump to any card.
* **Accessible.** Screen-reader actions, arrow-key swiping, reduced-motion
  support.

| Feature | What you get |
|---|---|
| **Swipeable cards** | `SwipeCardStack` and `SwipeCardController`: a behavior per direction, undo and rewind, drag overlays, and any card or stack look. |
| **OTP input** | `OtpCodeField`: typing, paste, autofill, long-press delete, and a verification lifecycle (processing, success, failure, restore) with haptics. |
| **Remembered emails** | History ranked by recency and use count, live suggestions with domain completion (`anna@gm` to `anna@gmail.com`), a UI-free controller, and a themed default field you can replace. |

## Install

```yaml
dependencies:
  craft_kit: ^0.1.0
```

```dart
import 'package:craft_kit/craft_kit.dart';
```

## Quick start: swipeable cards

```dart
SizedBox(
  height: 480, // the stack needs a bounded width and height
  child: SwipeCardStack<Profile>(
    items: profiles,
    itemBuilder: (context, profile, info) => ProfileCard(profile),
  ),
)
```

That is a working stack: left and right swipes dismiss the card, up and down
resist and spring back. Everything below is opt-in.

## Swipeable cards in depth

```dart
final controller = SwipeCardController();
final likeKey = GlobalKey();

SizedBox(
  height: 480,
  child: SwipeCardStack<Profile>(
    items: profiles,
    controller: controller,
    itemBuilder: (context, profile, info) => ProfileCard(profile),
    // What each direction does. A direction that is not listed cannot be
    // swiped: the card stretches with resistance and springs back.
    behaviors: {
      SwipeDirection.left: SwipeBehavior.dismiss(),
      SwipeDirection.right: SwipeBehavior.consume(
        target: SwipeTarget(key: likeKey),        // shrinks into this widget
        onArrive: (profile) => save(profile),
      ),
      SwipeDirection.up: SwipeBehavior.springBack(  // run a task, stay in deck
        onCommit: (event) => superLike(event.item),
      ),
      SwipeDirection.down: SwipeBehavior.undo(),    // bring the previous card back
    },
    overlayBuilder: (context, progress) => Stamps(progress), // LIKE / NOPE ...
    onSwipe: (event) => log(event.item, event.direction, event.outcome),
  ),
);

controller.swipe(SwipeDirection.right); // from a button: same behavior
controller.undo();                      // the last swiped card comes back
controller.rewind();                    // all of them, one after another
controller.jumpTo(ValueKey(profile));  // make another card the top card
```

**Behaviors** (`SwipeOutcome`): `dismiss` flies off; `consume` flies the card
into a `SwipeTarget` (falls back to `dismiss` if the target is not on screen);
`springBack` runs your callback and returns the card to the stack; `sendToBack`
re-queues it at the end; `undo` springs the dragged card back and brings the
previous card back in its place. Any behavior can take a `guard` to refuse an
item, and `onCommit`.

**Genie.** `SwipeTarget(effect: SwipeConsumeEffect.genie)` makes a consumed
card pour into its target like the macOS Dock minimize effect: the whole card funnels along the line from its centre to the target's centre point, the part nearest
that point narrowing first and the rest following in one smooth curve, warping the card's own
picture. Undoing it pours the card back out of the button. `genieLag` sets the
length of the funnel. (`shrink`, the default, is a plain shrinking flight.)

**Overlay.** `SwipeStampOverlay` is the classic: a coloured frame and a rotated
word (LIKE, NOPE...) in the corner that fade in with the drag, one `SwipeStamp`
per direction. `SwipeIntentOverlay` is a second, softer look: give it a `SwipeIntent` (colour,
icon, word) per direction and it draws a wash of colour
rising from the edge the card is heading to and a badge that grows with the
drag and arms, with its word, exactly when releasing would commit. It is a pure
function of the progress, so it is right at every moment of a drag, release or
programmatic swipe.

**Starting or jumping to a card.** `initialIndex` starts at a saved position and
`controller.jumpTo(key)` follows an outside change (a player moving to another
song, say). Cards before the top one count as swiped, so `undo` still brings
them back, sliding in from above.

**Rewind and undo.** Cards can be coming back while others are already on
top of them, so `rewind()` (optionally `count:` and `stagger:`) and rapid
undos overlap smoothly instead of jumping. Touching the top card stops a
rewind.

**Buttons that react.** Wrap the target in `SwipeReaction` to make it swell as a
card approaches (`state.approach`) and pulse when one arrives
(`state.arrival`). `controller.progress` and `controller.consuming` expose the
same live values.

**Feel.** Every movement is a spring that starts from the card's current
position and velocity, so a release never jumps, a card can be caught at any
moment (even mid-flight), and the next card can be grabbed while the last one
is still leaving. A release is judged by where the card is *heading*, so a
quick flick commits after a short distance and a slow drag has to go further.
Tune it with `SwipePhysics` (`smooth`, `snappy`, `bouncy`, or your own
springs, thresholds and tilt), and get a light haptic tick when a drag crosses
the commit threshold.

**Smoothness.** Cards are built once and moved with transforms only, so
`itemBuilder` is not called while a card is dragged or animated (tests assert
this), each card sits in a `RepaintBoundary`, springs are solved in closed form
so a late frame never distorts an animation, and nothing ticks while idle.

**Your own look.** `itemBuilder` builds any card; `SwipeStackLayout` decides how
the cards behind it sit (`CascadeLayout` is included; implement `slotAt(depth)`
for a fan, a carousel or anything else); `SwipeCardInfo` tells a card its depth
and gives it live progress. Items are matched by `itemKey`, so a parent rebuild
never resets the deck, and `onNeedMore` / `onPreload` support infinite feeds
and image precaching.

**Accessibility and input.** Screen readers get a custom action per direction,
arrow keys swipe while the stack has focus, mouse and trackpad drag work, and
reduced-motion settings make swipes finish immediately.

Directions are physical (left is always the left edge, also in RTL layouts).
The stack needs bounded width and height. Place it in an `IndexedStack` or
`Expanded`, not in a `TabBarView`/`PageView`, whose horizontal scrolling
competes with horizontal swipes.

## Remembered emails

Three layers, use as many as you want:

1. **`RememberedEmailStore`**: where the history lives.
   `StorageRememberedEmailStore` keeps it in any `CraftStorage`.
2. **`EmailFieldController`**: text, focus and live suggestions. No UI.
3. **`RememberedEmailField`**: a field plus suggestion chips.

```dart
final store = StorageRememberedEmailStore(PrefsStorage(prefs));
final email = EmailFieldController(store: store);

// UI, with the default themed field...
RememberedEmailField(controller: email);

// ...or keep your own text field and chips:
RememberedEmailField(
  controller: email,
  fieldBuilder: (context, controller, focusNode) =>
      MyTextField(controller: controller, focusNode: focusNode),
  suggestionBuilder: (context, suggestion, onTap) =>
      MyChip(label: suggestion.label, onTap: onTap),
);

// After a successful sign-in:
await email.rememberCurrentEmail();

// Hide suggestions while another step is on screen:
email.suggestionsEnabled = false;
```

`CraftStorage` is three methods. On top of `shared_preferences`:

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

Tune the behavior with `StorageRememberedEmailStore(maxEntries:, storageKey:,
isValidEmail:)` and `EmailSuggestionEngine(commonDomains:, maxSuggestions:,
isValidEmail:)`.

> Emails are personal data. Back `CraftStorage` with encrypted storage if that
> matters for your app, and offer a way to clear it (`store.clear()`,
> `store.forgetEmail(...)`).

## OTP input

```dart
final otp = OtpCodeController();

OtpCodeField(
  controller: otp,
  length: 6,
  onCompleted: (code) async {
    otp.beginProcessing();                 // collapse into a loader
    final ok = await verify(code);
    ok ? otp.showSuccess() : otp.showFailure(keepCode: false);
  },
);
```

* **Filling:** type, paste, or system autofill (`AutofillHints.oneTimeCode`).
  Or `otp.setCode(...)` from code, for example with an SMS-retrieval plugin.
  Text is cleaned: `"123 456"` and `"Order 22, code 654321"` both work, and
  Arabic-Indic digits are converted.
* **Lifecycle:** `beginProcessing`, `showSuccess` (or `await
  showSuccessAndWait()` to wait for the animation), `showFailure`,
  `restoreEditing`, plus `clear`, `requestFocus`, `unfocus`. `otp.phase`
  reports where the field is.
* **Look:** `style: null` derives colors from your `Theme`. Pass
  `const OtpStyle()` for the dark-surface look, or `OtpStyle.fromTheme(theme,
  base: ...)` to keep your own geometry. Everything else is configurable
  through `OtpAnimationSpec`, `OtpHaptics` and `OtpLabels` (localizable
  accessibility strings).

## Example

A runnable demo of every feature is in [`example/`](example). On the Swipe tab,
the tune button (top right) opens a **control center**: a draggable sheet that
changes everything live while you keep swiping, including what each direction
does, every physics number and spring, the stack layout, input and haptics,
feeds and preloading, a live readout of drag progress, and an event log.

## Contributing

Issues and pull requests are welcome. Run `flutter analyze` and `flutter test`
before sending a change.

## License

MIT, see [LICENSE](LICENSE).
