## 0.1.0

* Initial release.
* Remembered emails: `RememberedEmailStore`, `StorageRememberedEmailStore`,
  `EmailFieldController`, `EmailSuggestionEngine`, `RememberedEmailField`,
  `EmailSuggestionsView`, `EmailValidator`, `EmailInputFormatter`, and the
  pluggable `CraftStorage`.
* OTP input: `OtpCodeField` and `OtpCodeController` with paste, autofill and a
  processing / success / failure lifecycle; `OtpStyle`, `OtpAnimationSpec`,
  `OtpHaptics`, `OtpLabels`.
* Swipeable cards: `SwipeCardStack` and `SwipeCardController`, a spring-physics
  engine with:
  * a behavior per direction: dismiss, consume into a `SwipeTarget`, spring
    back after running a task, or send to the back (`SwipeBehavior`);
  * `SwipeReaction` for buttons that react to a card approaching and arriving;
  * releases judged by projected position, velocity handed to the animation,
    interruptible at any moment, and rubber-banding toward closed directions;
  * `SwipePhysics` (smooth, snappy, bouncy, or custom springs), `SwipeHaptics`,
    grab-point tilt, and per-direction progress for flicker-free overlays;
  * `SwipeStackLayout` (`CascadeLayout` included) and `SwipeCardInfo` for any
    stack look, `itemKey` based deck identity, undo, reset, `onNeedMore`,
    `onPreload`, keyboard, and screen-reader actions.
  Cards are built once and moved with transforms, so `itemBuilder` is not
  called while a card moves.
  * `SwipeBehavior.undo`: dragging a direction springs the card back and brings
    the previous card back (nothing happens with nothing to bring back).
  * `SwipeCardController.rewind({count, stagger})`: brings swiped cards back
    one after another. Returning cards keep moving when another is placed above
    them, so quick undos never jump.
  * `SwipeConsumeEffect.genie` (with `SwipeTarget.genieLag`): a consumed card
    pours into its target like the macOS Dock minimize effect, and back out on
    undo. Pictures kept for undoing are bounded and always released.
  * A card keeps its state as it moves from the back of the stack to the top
    and out, and a swipe rebuilds only the cards whose role changed.
  * Fixed: a card grabbed low flipped its tilt when released, and a card
    returned by undo did not keep the tilt it left with.
* `OtpCodeController.showSuccessAndWait()` returns a future that completes when
  the success animation ends.
* `OtpStyle.canvasVerticalPadding` (default 44) and `OtpStyle.resultGlow`
  (default `OtpResultGlow.classic`). `OtpStyle.fromTheme` now selects a tighter
  field height and a gradient-tinted result glow, and has fuller light/dark
  surfaces and result gradients. `const OtpStyle()` is unchanged.
* `StorageRememberedEmailStore.onCorruptData` reports discarded data; loading
  now recovers from any decode error.
* `RememberedEmailField`: `invalidEmailMessage`, `autovalidateMode`,
  `textInputAction` and `suggestionPadding`.
