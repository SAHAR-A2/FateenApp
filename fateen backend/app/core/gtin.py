"""GS1 check digit for GTIN-8/12/13/14 (EAN-8, UPC-A, EAN-13, GTIN-14)."""

GTIN_LENGTHS = (8, 12, 13, 14)


def has_valid_check_digit(barcode: str) -> bool:
    """True when `barcode` is an all-digit GTIN whose last digit matches the
    GS1 mod-10 check digit. Retail scanners reject any other value, so a
    stored barcode failing this can never be scanned by a user."""
    if not barcode or not barcode.isdigit() or len(barcode) not in GTIN_LENGTHS:
        return False
    body, check = barcode[:-1], int(barcode[-1])
    # Weights 3,1,3,1... starting from the digit next to the check digit.
    total = sum(int(d) * (3 if i % 2 == 0 else 1) for i, d in enumerate(reversed(body)))
    return (10 - total % 10) % 10 == check
