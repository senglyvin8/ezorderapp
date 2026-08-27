import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/models/merchant_code.dart';

/// The merchant ID is the one string in this product that gets read down a
/// phone line, so what counts is what survives the reading.
///
/// Mirrors `normalize_merchant_code()` in
/// `supabase/migrations/0011_merchant_code.sql`. If one of these changes, the
/// other has to change with it — a device that normalises differently from the
/// database binds to nothing and cannot say why.
void main() {
  const code = 'EZ-4K7Q2M';

  test('the canonical form is what it already is', () {
    expect(MerchantCode.normalize(code), code);
  });

  test('however it was typed', () {
    for (final typed in [
      'ez-4k7q2m',
      '4K7Q2M', // the prefix left off
      'EZ 4K7 Q2M', // spaces where they fell
      '  ez4k7q2m  ',
      'EZ–4K7Q2M', // an en dash, from a phone that helpfully corrected it
    ]) {
      expect(MerchantCode.normalize(typed), code, reason: typed);
    }
  });

  test('an O heard for a zero, and an I or L for a one', () {
    expect(MerchantCode.normalize('EZ-4KOQ2M'), 'EZ-4K0Q2M');
    expect(MerchantCode.normalize('EZ-4KIQ2M'), 'EZ-4K1Q2M');
    expect(MerchantCode.normalize('EZ-4KLQ2M'), 'EZ-4K1Q2M');
    // Every ambiguous character at once still lands somewhere real, because
    // the mapping is what makes them unambiguous in the first place.
    expect(MerchantCode.normalize('EZ-OI1L0O'), 'EZ-011100');
  });

  test('U is not in the alphabet, so a code can never spell anything', () {
    expect(MerchantCode.normalize('EZ-FUQ2M4'), isNull);
    expect(MerchantCode.alphabet.contains('U'), isFalse);
    for (final ambiguous in ['I', 'L', 'O']) {
      expect(MerchantCode.alphabet.contains(ambiguous), isFalse,
          reason: '$ambiguous is not worth an argument on a bad line');
    }
  });

  test('wrong lengths are refused rather than padded or trimmed', () {
    expect(MerchantCode.normalize(''), isNull);
    expect(MerchantCode.normalize('EZ-'), isNull);
    expect(MerchantCode.normalize('4K7Q2'), isNull);
    expect(MerchantCode.normalize('4K7Q2MX'), isNull);
  });

  test('a body that starts with EZ survives', () {
    // Only an eight-character string loses its prefix, so a code whose first
    // two characters happen to be E and Z is not quietly shortened.
    expect(MerchantCode.normalize('EZ4K7Q'), 'EZ-EZ4K7Q');
    expect(MerchantCode.normalize('EZ-EZ4K7Q'), 'EZ-EZ4K7Q');
  });

  test('display never invents a code it cannot make sense of', () {
    expect(MerchantCode.display('ez-4k7q2m'), code);
    expect(MerchantCode.display('nonsense'), 'NONSENSE');
  });
}
