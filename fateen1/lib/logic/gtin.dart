/// GS1 check digit for GTIN-8/12/13/14 (EAN-8, UPC-A, EAN-13, GTIN-14).
/// Mirrors app/core/gtin.py in the backend.
bool hasValidGtinCheckDigit(String barcode) {
  if (!RegExp(r'^\d+$').hasMatch(barcode)) return false;
  if (![8, 12, 13, 14].contains(barcode.length)) return false;
  final digits = barcode.split('').map(int.parse).toList();
  final check = digits.removeLast();
  var total = 0;
  for (var i = 0; i < digits.length; i++) {
    final digit = digits[digits.length - 1 - i];
    total += i.isEven ? digit * 3 : digit;
  }
  return (10 - total % 10) % 10 == check;
}
