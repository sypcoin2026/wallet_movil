import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/digests/blake2b.dart';
import 'package:sypc_wallet/domain/sypc_address_validator.dart';

void main() {
  final rows = File('test/fixtures/native_address_vectors.tsv')
      .readAsLinesSync()
      .map((line) => line.split('\t'))
      .toList();
  for (final row in rows) {
    test('Native SYPC vector: ${row[0]}', () {
      final inspected = SypcAddressValidator.inspect(row[2]);
      expect(inspected.encodingValid, row[1] == 'OK');
      if (row[1] != 'OK') {
        // PointyCastle reports both field overflow and non-residues as a
        // point error; the accept/reject verdict matches the native oracle.
        expect(inspected.rejectionCode,
            row[1] == 'PUBLIC_KEY_FIELD' ? 'PUBLIC_KEY_CURVE' : row[1]);
      } else {
        final expected = row[0].contains('p2sh')
            ? SypcAddressType.p2sh
            : row[0].contains('p2pk')
                ? SypcAddressType.p2pk
                : SypcAddressType.p2s;
        expect(inspected.type, expected);
        expect(inspected.publicKeyValidated, expected == SypcAddressType.p2pk);
        expect(inspected.scriptValidated, isFalse);
        expect(inspected.needsScriptReview, expected == SypcAddressType.p2s);
      }
    });
  }
  test(
      'Native long P2S exceeds 110 and 5000 characters without false script claims',
      () {
    final row = rows.singleWhere((r) => r[0] == 'native_long_p2s_120');
    expect(row[2].length, greaterThan(5000));
    final result = SypcAddressValidator.inspect(row[2]);
    expect(result.encodingValid, isTrue);
    expect(result.scriptValidated, isFalse);
    expect(result.label, contains('script NO validado'));
  });
  test('BLAKE2b-256 known-answer vectors differ from truncated BLAKE2b-512',
      () {
    // Independent hashlib / published BLAKE2 known answers.
    String digest(String text) => Blake2bDigest(digestSize: 32)
        .process(Uint8List.fromList(utf8.encode(text)))
        .map((n) => n.toRadixString(16).padLeft(2, '0'))
        .join();
    expect(digest(''),
        '0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8');
    expect(digest('abc'),
        'bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319');
  });
  final extra = jsonDecode(
          File('test/fixtures/independent_envelopes.json').readAsStringSync())
      as List;
  for (final row in extra) {
    test('Independent Python envelope: ${row['name']}', () {
      final result = SypcAddressValidator.inspect(row['address'] as String);
      expect(result.encodingValid, row['encodingValid']);
      expect(result.scriptValidated, isFalse);
    });
  }
  test(
      'Bitcoin Base58, forbidden characters, whitespace and leading zeros fail',
      () {
    for (final bad in [
      '1BoatSLRHtKNngkdXEeobR76b53LETtpyT',
      '3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy',
      '0',
      'O',
      'I',
      'l',
      '😀',
      '\n',
      '${rows.first[2]}\n',
      '1${rows.first[2]}'
    ]) {
      expect(SypcAddressValidator.inspect(bad).encodingValid, isFalse,
          reason: bad);
    }
  });
}
