import 'package:flutter/material.dart';

import 'email_validator.dart';
import 'remembered_email_store.dart';

/// An email text field with suggestions from a [RememberedEmailStore] and a
/// "remember me" checkbox.
///
/// The field only *reads* and toggles the store. To save the email, call
/// [RememberedEmailStore.rememberIfEnabled] after a successful sign-in.
class RememberEmailField extends StatefulWidget {
  /// Creates the field.
  const RememberEmailField({
    super.key,
    required this.store,
    this.controller,
    this.decoration = const InputDecoration(labelText: 'Email'),
    this.rememberLabel = 'Remember me',
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.prefillLast = true,
    this.autofocus = false,
  });

  /// Source of suggestions and the remember flag.
  final RememberedEmailStore store;

  /// Optional controller; one is created if omitted.
  final TextEditingController? controller;

  /// Decoration for the text field.
  final InputDecoration decoration;

  /// Label of the remember checkbox.
  final String rememberLabel;

  /// Form validator. Defaults to [EmailValidator.validate].
  final FormFieldValidator<String>? validator;

  /// Keyboard action button.
  final TextInputAction textInputAction;

  /// Called when the user submits the field.
  final ValueChanged<String>? onSubmitted;

  /// Fill the field with the last remembered email when it is empty.
  final bool prefillLast;

  /// Whether to focus the field on first build.
  final bool autofocus;

  @override
  State<RememberEmailField> createState() => _RememberEmailFieldState();
}

class _RememberEmailFieldState extends State<RememberEmailField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.prefillLast &&
        _controller.text.isEmpty &&
        widget.store.rememberEnabled) {
      final last = widget.store.lastEmail;
      if (last != null) _controller.text = last;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            RawAutocomplete<String>(
              textEditingController: _controller,
              focusNode: _focusNode,
              optionsBuilder: (value) => widget.store.rememberEnabled
                  ? widget.store.suggestions(value.text)
                  : const Iterable<String>.empty(),
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: widget.autofocus,
                  decoration: widget.decoration,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: widget.textInputAction,
                  autofillHints: const <String>[AutofillHints.email],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: widget.validator ?? EmailValidator.validate,
                  onFieldSubmitted: (value) {
                    onSubmit();
                    widget.onSubmitted?.call(value);
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 220,
                        maxWidth: 480,
                      ),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: <Widget>[
                          for (final email in options)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.history, size: 18),
                              title: Text(email),
                              trailing: IconButton(
                                tooltip: 'Forget',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => widget.store.forget(email),
                              ),
                              onTap: () => onSelected(email),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(widget.rememberLabel),
              value: widget.store.rememberEnabled,
              onChanged: (value) =>
                  widget.store.setRememberEnabled(value ?? false),
            ),
          ],
        );
      },
    );
  }
}
