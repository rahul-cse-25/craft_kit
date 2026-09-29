import 'package:flutter/material.dart';

import '../logic/email_suggestion_engine.dart';

/// Builds one suggestion. Call [onTap] to select it.
typedef EmailSuggestionItemBuilder =
    Widget Function(
      BuildContext context,
      EmailSuggestionItem suggestion,
      VoidCallback onTap,
    );

/// Lays suggestions out as a wrapping row of chips.
///
/// The default chip follows the ambient [Theme]. Pass [itemBuilder] to render
/// your own chip without touching layout or selection logic.
class EmailSuggestionsView extends StatelessWidget {
  /// Creates the view.
  const EmailSuggestionsView({
    super.key,
    required this.suggestions,
    required this.onSelected,
    this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.spacing = 8,
    this.runSpacing = 8,
  });

  /// What to show.
  final List<EmailSuggestionItem> suggestions;

  /// Called when a suggestion is tapped.
  final ValueChanged<EmailSuggestionItem> onSelected;

  /// Custom chip. Defaults to [DefaultEmailSuggestionChip].
  final EmailSuggestionItemBuilder? itemBuilder;

  /// Space around the chips.
  final EdgeInsetsGeometry padding;

  /// Horizontal gap between chips.
  final double spacing;

  /// Vertical gap between chip rows.
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final EmailSuggestionItemBuilder build =
        itemBuilder ??
        (BuildContext context, EmailSuggestionItem item, VoidCallback onTap) =>
            DefaultEmailSuggestionChip(suggestion: item, onTap: onTap);

    return Padding(
      padding: padding,
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: <Widget>[
          for (final EmailSuggestionItem suggestion in suggestions)
            build(context, suggestion, () => onSelected(suggestion)),
        ],
      ),
    );
  }
}

/// The stock suggestion chip: a pill colored from the ambient [Theme], with a
/// history icon for remembered emails.
class DefaultEmailSuggestionChip extends StatelessWidget {
  /// Creates the chip.
  const DefaultEmailSuggestionChip({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  /// What the chip shows.
  final EmailSuggestionItem suggestion;

  /// Called when tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isHistory = suggestion.kind == EmailSuggestionKind.history;

    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isHistory) ...<Widget>[
                Icon(Icons.history, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
              ],
              Text(
                suggestion.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
