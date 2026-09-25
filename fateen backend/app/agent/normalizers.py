import re


def normalize_barcode(barcode: str) -> str:
    return re.sub(r"[^0-9]", "", barcode.strip())


def normalize_name(name: str) -> str:
    return name.strip().lower()


def normalize_code(code: str) -> str:
    return code.strip().lower()
