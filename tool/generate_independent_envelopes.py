"""Public negative fixtures independent of Dart; no keys or network access."""
import hashlib
import json
from pathlib import Path

ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def base58(raw):
    number = int.from_bytes(raw, "big")
    result = ""
    while number:
        number, digit = divmod(number, 58)
        result = ALPHABET[digit] + result
    zeros = len(raw) - len(raw.lstrip(bytes([0])))
    return "1" * zeros + result


def envelope(payload, mode):
    if mode == "blake256":
        digest = hashlib.blake2b(payload, digest_size=32).digest()
    elif mode == "blake512":
        digest = hashlib.blake2b(payload).digest()
    else:
        digest = hashlib.sha256(hashlib.sha256(payload).digest()).digest()
    return base58(payload + digest[:4])


key = bytes.fromhex("0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
CASES = [
    ("truncated_blake512", bytes([49]) + key, "blake512", False),
    ("bitcoin_double_sha256", bytes([49]) + key, "sha256d", False),
    ("p2s_unparsed", bytes([51, 255]), "blake256", True),
    ("p2s_empty", bytes([51]), "blake256", False),
    ("p2s_oversize", bytes([51]) + bytes(4097), "blake256", False),
    ("type_zero", bytes([48]) + key, "blake256", False),
]
if __name__ == "__main__":
    output = [{"name": name, "address": envelope(payload, mode), "encodingValid": valid}
              for name, payload, mode, valid in CASES]
    destination = Path(__file__).resolve().parents[1] / "test/fixtures/independent_envelopes.json"
    destination.write_text(json.dumps(output, indent=2) + "\n")
