/// Lightweight email validation helpers.
abstract final class EmailValidator {
  static final RegExp _pattern = RegExp(
    r"^[A-Za-z0-9.!#$%&*+/=?^_`{|}~'-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}"
    r'[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  /// Whether [email] (after trimming) looks like a valid email address.
  static bool isValid(String? email) {
    if (email == null) return false;
    return _pattern.hasMatch(email.trim());
  }

  /// A `FormField` validator: returns [message] when [email] is invalid.
  static String? validate(
    String? email, {
    String message = 'Enter a valid email address',
  }) => isValid(email) ? null : message;

  /// Normalizes [email] for storage and comparison (trimmed, lower-cased).
  static String normalize(String email) => email.trim().toLowerCase();
}
