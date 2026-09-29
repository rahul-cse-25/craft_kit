import 'package:flutter/material.dart';

import '../email_input_formatter.dart';
import '../email_validator.dart';
import '../logic/email_field_controller.dart';
import '../logic/email_suggestion_engine.dart';
import 'email_suggestions_view.dart';

/// Builds the text field. Bind [controller] and [focusNode] to it.
///
/// This is the seam that lets an app keep its own text-field widget:
/// `fieldBuilder: (context, controller, focusNode) => AppTextField(...)`.
typedef EmailFieldBuilder =
    Widget Function(
      BuildContext context,
      TextEditingController controller,
      FocusNode focusNode,
    );

/// An email field with remembered-email suggestions underneath.
///
/// The text field itself is replaceable through [fieldBuilder]; the default is
/// a themed [TextFormField] with an email keyboard, autofill hints, an
/// [EmailInputFormatter] and [EmailValidator.validate].
class RememberedEmailField extends StatelessWidget {
  /// Creates the field.
  const RememberedEmailField({
    super.key,
    required this.controller,
    this.fieldBuilder,
    this.suggestionBuilder,
    this.enabled = true,
    this.onSubmitted,
    this.decoration = const InputDecoration(labelText: 'Email'),
    this.emptyGap = 16,
    this.textInputAction = TextInputAction.next,
    this.invalidEmailMessage = 'Please enter a valid email',
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.suggestionPadding = const EdgeInsets.symmetric(vertical: 8),
  });

  /// Text, focus and suggestions.
  final EmailFieldController controller;

  /// Custom text field. Overrides [decoration], [enabled] and [onSubmitted],
  /// which only configure the default field.
  final EmailFieldBuilder? fieldBuilder;

  /// Custom suggestion chip.
  final EmailSuggestionItemBuilder? suggestionBuilder;

  /// Whether the field and its suggestions are active.
  final bool enabled;

  /// Called when the user submits the default field.
  final ValueChanged<String>? onSubmitted;

  /// Decoration of the default field.
  final InputDecoration decoration;

  /// Height reserved under the field while there are no suggestions, so the
  /// layout does not jump when chips appear.
  final double emptyGap;

  /// Keyboard action of the default field.
  final TextInputAction textInputAction;

  /// Error text of the default field's validator.
  final String invalidEmailMessage;

  /// When the default field validates.
  final AutovalidateMode autovalidateMode;

  /// Space around the suggestion chips.
  final EdgeInsetsGeometry suggestionPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        fieldBuilder?.call(
              context,
              controller.textController,
              controller.focusNode,
            ) ??
            TextFormField(
              controller: controller.textController,
              focusNode: controller.focusNode,
              enabled: enabled,
              decoration: decoration,
              keyboardType: TextInputType.emailAddress,
              textInputAction: textInputAction,
              autofillHints: const <String>[AutofillHints.email],
              inputFormatters: const <EmailInputFormatter>[
                EmailInputFormatter(),
              ],
              onFieldSubmitted: onSubmitted,
              autovalidateMode: autovalidateMode,
              validator:
                  (String? value) => EmailValidator.validate(
                    value,
                    message: invalidEmailMessage,
                  ),
            ),
        ValueListenableBuilder<List<EmailSuggestionItem>>(
          valueListenable: controller.suggestions,
          builder: (BuildContext context, List<EmailSuggestionItem> items, _) {
            if (!enabled || items.isEmpty) {
              return SizedBox(height: emptyGap);
            }
            return EmailSuggestionsView(
              suggestions: items,
              onSelected: controller.selectSuggestion,
              itemBuilder: suggestionBuilder,
              padding: suggestionPadding,
            );
          },
        ),
      ],
    );
  }
}
