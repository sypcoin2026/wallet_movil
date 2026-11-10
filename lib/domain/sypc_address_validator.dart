import 'dart:typed_data';

import 'package:pointycastle/digests/blake2b.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';

enum SypcAddressType { p2pk, p2sh, p2s }

/// Local encoding inspection only: never proves ownership, funds or consensus.
class SypcAddressInspection {
  final SypcAddressType? type;
  final String? rejectionCode;
  const SypcAddressInspection._(this.type, this.rejectionCode);

  bool get encodingValid => type != null && rejectionCode == null;
  bool get publicKeyValidated => encodingValid && type == SypcAddressType.p2pk;

  /// No ErgoTree parser is integrated. In particular, P2S is only an envelope.
  bool get scriptValidated => false;
  bool get needsScriptReview => encodingValid && type == SypcAddressType.p2s;

  String get label {
    if (!encodingValid) return 'REQUIERE REVISION · $rejectionCode';
    if (needsScriptReview) {
      return 'P2S · codificacion valida · script NO validado';
    }
    return '${type!.name.toUpperCase()} · codificacion SYPC valida · fondos NO verificados';
  }
}

/// Private SYPC testnet envelope (0x30), matching the isolated native candidate.
/// Limits are defensive parser budgets, not a consensus ErgoTree size rule.
class SypcAddressValidator {
  const SypcAddressValidator._();
  static const int networkPrefix = 48;
  static const int maxEncodedLength = 6000;
  static const int maxContentBytes = 4096;
  static const String _alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  static final _curve = ECCurve_secp256k1().curve;

  /// Strict input: whitespace, URI prefixes and non-Base58 characters fail.
  static SypcAddressInspection inspect(String address) {
    SypcAddressInspection reject(String code) =>
        SypcAddressInspection._(null, code);
    if (address.isEmpty || address.length > maxEncodedLength) {
      return reject('BASE58_LENGTH');
    }
    var number = BigInt.zero;
    final radix = BigInt.from(58);
    for (final unit in address.codeUnits) {
      final digit = _alphabet.indexOf(String.fromCharCode(unit));
      if (digit < 0) return reject('BASE58_CHARACTER');
      number = number * radix + BigInt.from(digit);
    }
    var leadingZeros = 0;
    while (leadingZeros < address.length && address[leadingZeros] == '1') {
      leadingZeros++;
    }
    final reversed = <int>[];
    final mask = BigInt.from(255);
    while (number > BigInt.zero) {
      reversed.add((number & mask).toInt());
      number >>= 8;
    }
    final raw = Uint8List.fromList([
      ...List<int>.filled(leadingZeros, 0),
      ...reversed.reversed,
    ]);
    if (raw.length < 6 || raw.length > maxContentBytes + 5) {
      return reject('ADDRESS_SIZE');
    }
    if ((raw[0] & 0xf0) != networkPrefix) {
      return reject('ADDRESS_OTHER_NETWORK');
    }
    final kind = raw[0] & 0x0f;
    if (kind < 1 || kind > 3) return reject('ADDRESS_TYPE');
    final payload = Uint8List.sublistView(raw, 0, raw.length - 4);
    // digestSize is in BYTES. The 32-byte parameter enters BLAKE2's state;
    // truncating a default 64-byte digest would give a different checksum.
    final digest = Blake2bDigest(digestSize: 32).process(payload);
    var difference = 0;
    for (var i = 0; i < 4; i++) {
      difference |= digest[i] ^ raw[payload.length + i];
    }
    if (difference != 0) return reject('CHECKSUM');
    final body = Uint8List.sublistView(payload, 1);
    if (kind == 1) {
      if (body.length != 33 || (body[0] != 2 && body[0] != 3)) {
        return reject('PUBLIC_KEY_FORMAT');
      }
      try {
        // PointyCastle rejects field overflow and non-residues on secp256k1.
        // This curve has cofactor one; a finite decoded point is in the group.
        final point = _curve.decodePoint(body);
        if (point == null || point.isInfinity) {
          return reject('PUBLIC_KEY_CURVE');
        }
      } on ArgumentError {
        return reject('PUBLIC_KEY_CURVE');
      }
    } else if (kind == 2 && body.length != 24) {
      return reject('P2SH_LENGTH');
    }
    return SypcAddressInspection._(SypcAddressType.values[kind - 1], null);
  }
}
