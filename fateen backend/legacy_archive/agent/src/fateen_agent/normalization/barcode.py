"""Barcode normalization and validation (GTIN family)."""

from __future__ import annotations

import re

_BARCODE_DIGITS = re.compile(r"^\d+$")


def normalize_barcode(value: str) -> str:
    """Strip whitespace/separators and keep digits only."""
    if not value:
        return ""
    return re.sub(r"[^\d]", "", value.strip())


def is_valid_gtin(value: str) -> bool:
    """Check GTIN-8/12/13/14 shape and check digit."""
    digits = normalize_barcode(value)
    if len(digits) not in (8, 12, 13, 14):
        return False
    if not _BARCODE_DIGITS.match(digits):
        return False
    return _check_digit_ok(digits)


def gtin_type(digits: str) -> str:
    n = len(digits)
    if n == 8:
        return "gtin_8"
    if n == 12:
        return "gtin_12"
    if n == 13:
        return "gtin_13"
    if n == 14:
        return "gtin_14"
    return "unknown"


def _check_digit_ok(digits: str) -> bool:
    """Validate the final check digit using the GTIN algorithm."""
    payload = digits[:-1]
    expected = _check_digit(payload)
    return expected == int(digits[-1])


def _check_digit(payload: str) -> int:
    total = 0
    # GTIN check digit: weights 3,1,3,1,... from the right.
    for i, ch in enumerate(reversed(payload)):
        weight = 3 if i % 2 == 0 else 1
        total += int(ch) * weight
    return (10 - (total % 10)) % 10
