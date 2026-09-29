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
