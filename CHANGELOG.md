## 0.1.0

* Initial release.
* Remembered emails: `RememberedEmailStore`, `StorageRememberedEmailStore`,
  `EmailFieldController`, `EmailSuggestionEngine`, `RememberedEmailField`,
  `EmailSuggestionsView`, `EmailValidator`, `EmailInputFormatter`, and the
  pluggable `CraftStorage`.
* OTP input: `OtpCodeField` and `OtpCodeController` with paste, autofill and a
  processing / success / failure lifecycle; `OtpStyle`, `OtpAnimationSpec`,
  `OtpHaptics`, `OtpLabels`.
* Swipeable cards (preview): `SwipeCardStack`, `SwipeCardController`.
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
