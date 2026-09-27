import 'package:fateen/logic/gtin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts valid GTINs of every retail length', () {
    for (final code in ['96385074', '036000291452', '4006381333931', '6281007031585']) {
      expect(hasValidGtinCheckDigit(code), isTrue, reason: code);
    }
  });

  test('rejects a wrong check digit, bad length or non-digits', () {
    for (final code in ['6281007031580', '4006381333932', '1234567', '12345678901', 'abcdefgh', '']) {
      expect(hasValidGtinCheckDigit(code), isFalse, reason: code);
    }
  });
}
