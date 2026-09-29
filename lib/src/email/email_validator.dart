/// Lightweight email validation helpers.
///
/// The check is intentionally simple (one `@`, a dotted domain, an alphabetic
/// top-level domain of two or more letters). Every API that validates takes an
/// override, so apps with stricter rules can plug their own.
abstract final class EmailValidator {
  static final RegExp _pattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Whether [email] looks like a valid email address.
  static bool isValid(String? email) {
    if (email == null || email.isEmpty) return false;
    return _pattern.hasMatch(email);
  }

  /// A `FormField` validator: returns [message] when [email] is invalid.
  static String? validate(
    String? email, {
    String message = 'Please enter a valid email',
  }) => isValid(email) ? null : message;

  /// Normalizes [email] for storage and comparison (trimmed, lower-cased).
  static String normalize(String email) => email.trim().toLowerCase();
}
