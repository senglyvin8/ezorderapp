/// The merchant ID: `EZ-4K7Q2M`.
///
/// One restaurant, one code, forever. It is what an owner reads down a phone
/// to a new cashier, what a device is bound with, and what support asks for.
/// Deliberately not the slug — the slug is in printed QR codes and in URLs, it
/// is chosen when the restaurant is provisioned, and a merchant who rebrands
/// will one day want to change it. This may not change, ever.
///
/// The alphabet is Crockford base32: digits and letters, without I, L, O and
/// U. Nobody has to decide whether that was a one or an ell, and the reading
/// of it survives a bad line.
///
/// Mirrors `normalize_merchant_code()` in
/// `supabase/migrations/0011_merchant_code.sql`. Change one and you must
/// change the other.
abstract class MerchantCode {
  static const String prefix = 'EZ-';

  /// The six characters a code is drawn from. No I, L, O or U.
  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  static const int bodyLength = 6;

  /// Canonical form, or null when what was typed cannot be a code.
  ///
  /// Forgiving on the way in on purpose: lower case, spaces, a missing prefix
  /// and an O typed where a zero belongs are all somebody doing their best
  /// with a code that was read aloud to them.
  static String? normalize(String raw) {
    var value = raw.replaceAll(RegExp('[^0-9A-Za-z]'), '').toUpperCase();

    // The prefix is presentation. Drop it only when what is left is the right
    // length, so a body that happens to start with EZ survives.
    if (value.length == bodyLength + 2 && value.startsWith('EZ')) {
      value = value.substring(2);
    }
    if (value.length != bodyLength) return null;

    value = value
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('O', '0');

    for (final unit in value.codeUnits) {
      if (!alphabet.contains(String.fromCharCode(unit))) return null;
    }
    return '$prefix$value';
  }

  static bool isValid(String raw) => normalize(raw) != null;

  /// What to show. Codes are stored canonical, so this is only a guard against
  /// a value that arrived from somewhere older or stranger.
  static String display(String code) => normalize(code) ?? code.toUpperCase();
}
