# Moving bump_fm_app onto craft_kit

craft_kit's OTP and email features were extracted from `bump_fm_app`. The class
names and the stored data format are kept, so the migration is mostly import
changes. Nothing below is required for craft_kit itself; it is the checklist
for the app.

## What was decoupled, and how

| Was in Bump | Coupling | Now in craft_kit |
|---|---|---|
| `SharedPrefsRememberedEmailStore(SharedPreferences)` | Hard dependency on `shared_preferences` | `StorageRememberedEmailStore(CraftStorage)`. Implement `CraftStorage` (3 methods) on any storage. |
| `Validators.isValidEmail` | Bump helper | `EmailValidator.isValid` (same regex). Every API also accepts an `isValidEmail` override. |
| `EmailFormatter` | Bump helper | `EmailInputFormatter` (same behavior). |
| `LoginEmailFieldController`, `setOtpStepActive` | "Login" and "OTP step" leaked into the name | `EmailFieldController`, `suggestionsEnabled` setter. |
| `LoginEmailFieldSection` uses `AppTextField` | Bump widget | `RememberedEmailField` with a `fieldBuilder` slot: keep `AppTextField`. |
| `EmailSuggestionsSection` uses `BumpColors`, `GradientText` | Bump theme | `EmailSuggestionsView` with an `itemBuilder` slot; default chip follows `Theme`. |
| `OtpStyle()` defaults are white-on-dark | Only right on Bump's dark theme | `OtpCodeField(style: null)` derives colors from `Theme`. `const OtpStyle()` is unchanged. |
| Hard-coded English semantics strings | Not localizable | `OtpLabels`. |
| `otp_demo_screen.dart` (imports `bump_theme`, has `main()`) exported from the barrel | Demo in the public API | Removed. The example app replaces it. |
| Paste "Order 22, code 654321" produced `226543` | Every digit was kept | A standalone run of exactly `length` digits wins. All other inputs behave as before. |

## Keeping Bump's UI identical

1. **OTP style.** Bump relies on the old default look. Pass it explicitly:

   ```dart
   OtpCodeField(
     style: const OtpStyle(),   // the dark look Bump has today
     ...
   )
   ```

   If `login_otp_bottom_sheet.dart` sets no style, that one line is the only
   visual change needed.

2. **Stored emails.** Keep users' history by reusing Bump's key:

   ```dart
   StorageRememberedEmailStore(
     PrefsStorage(sl<SharedPreferences>()),
     storageKey: 'auth_remembered_emails_v1',
     maxEntries: 16,
   )
   ```

   The JSON format is identical (`email`, `use_count`, `last_used_at_epoch_ms`).

3. **The email field.** Keep `AppTextField` and the chips:

   ```dart
   RememberedEmailField(
     controller: emailController,
     enabled: enabled,
     fieldBuilder: (context, controller, focusNode) => AppTextField(
       controller: controller,
       focusNode: focusNode,
       /* the same arguments as today */
     ),
     suggestionBuilder: (context, suggestion, onTap) =>
         YourBumpChip(suggestion: suggestion, onTap: onTap),
     emptyGap: 16,
   )
   ```

## The `CraftStorage` adapter

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

## Renames at call sites

| Bump | craft_kit |
|---|---|
| `RememberedEmailStore` (abstract class) | `RememberedEmailStore` (interface; adds `forgetEmail`, `clear`) |
| `SharedPrefsRememberedEmailStore(prefs)` | `StorageRememberedEmailStore(PrefsStorage(prefs), storageKey: ...)` |
| `LoginEmailFieldController(rememberedEmailStore: s)` | `EmailFieldController(store: s)` |
| `controller.setOtpStepActive(v)` | `controller.suggestionsEnabled = !v` |
| `EmailFormatter()` | `EmailInputFormatter()` |
| `Validators.isValidEmail` (email use) | `EmailValidator.isValid` |
| `import '.../core/widgets/otp/otp.dart'` | `import 'package:craft_kit/craft_kit.dart'` |

`OtpCodeField`, `OtpCodeController`, `OtpStyle`, `OtpAnimationSpec`,
`OtpHaptics`, `OtpPhase`, `EmailSuggestionEngine`, `EmailSuggestionItem`,
`EmailSuggestionKind` and `RememberedEmailEntry` keep their names and
behavior.

## Not moved

* `login_otp_bottom_sheet.dart` uses `AuthCubitV1`, `AppButton` and
  `BumpColors`. It is app UI built *on* the OTP field and stays in Bump.
* `opt_digit.dart` (`OtpDigitFields`, one `TextField` per digit) is a separate,
  older widget that depends on `ClaritySensitiveMask` and `BumpTextStyle`. It
  was not part of this extraction. Check whether it is still used; if not,
  delete it.
