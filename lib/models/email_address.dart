/// A login address, checked the small amount that is worth checking.
///
/// Deliberately not a full RFC 5322 pattern. The only thing an over-strict
/// check achieves is turning away somebody whose address is unusual but real,
/// and the address is proved by being able to sign in with it — not by
/// matching a regular expression here.
abstract class EmailAddress {
  static final RegExp _shape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Canonical form, or null when it plainly is not an address.
  static String? normalize(String raw) {
    final value = raw.trim().toLowerCase();
    return _shape.hasMatch(value) ? value : null;
  }

  static bool isValid(String raw) => normalize(raw) != null;
}
