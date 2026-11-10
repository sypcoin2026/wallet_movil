import 'package:flutter_test/flutter_test.dart';
import 'package:sypc_wallet/domain/sypc_watch_only_guard.dart';

void main() {
  final now = DateTime.utc(2026, 11, 9, 18);
  final valid = <String, dynamic>{
    'schemaVersion': 1,
    'networkId': SypcReadOnlyPolicy.networkId,
    'genesisId': SypcReadOnlyPolicy.genesisId,
    'fullHeight': 300,
    'headersHeight': 300,
    'bestFullBlockId': 'a' * 64,
    'stateRoot': 'b' * 64,
    'observedAtUnixMs': now.millisecondsSinceEpoch,
    'isSynced': true,
    'isMining': false,
  };

  SypcTipInspection inspect(Map<String, dynamic> input) =>
      SypcReadOnlyGuard.inspect(input, nowUtc: now);

  test('Well-formed local report is structurally admissible', () {
    final result = inspect(valid);
    expect(result.accepted, isTrue);
    expect(result.tip?.fullHeight, 300);
  });
  test('A foreign network fails closed', () {
    final result = inspect({...valid, 'networkId': 'MainNet'});
    expect(result.rejectionCode, 'NETWORK_MISMATCH');
  });
  test('A different genesis fails closed', () {
    final result = inspect({...valid, 'genesisId': 'f' * 64});
    expect(result.rejectionCode, 'GENESIS_MISMATCH');
  });
  test('Height cannot be negative or ahead of headers', () {
    expect(inspect({...valid, 'fullHeight': -1}).accepted, isFalse);
    expect(inspect({...valid, 'fullHeight': 301}).accepted, isFalse);
    expect(inspect({...valid, 'headersHeight': 300.0}).accepted, isFalse);
    expect(inspect({...valid, 'headersHeight': 301}).accepted, isFalse);
  });
  test('Hash values must be canonical 32-byte lowercase hex', () {
    expect(inspect({...valid, 'bestFullBlockId': 'xyz'}).accepted, isFalse);
    expect(inspect({...valid, 'stateRoot': 'F' * 64}).accepted, isFalse);
  });
  test('Old or future-dated reports cannot silently pass', () {
    final old = now.subtract(const Duration(minutes: 11));
    final future = now.add(const Duration(minutes: 1));
    expect(inspect({...valid, 'observedAtUnixMs':
        old.millisecondsSinceEpoch}).accepted, isFalse);
    expect(inspect({...valid, 'observedAtUnixMs':
        future.millisecondsSinceEpoch}).accepted, isFalse);
  });
  test('Reject unsynced node and mining status', () {
    expect(inspect({...valid, 'isSynced': false}).accepted, isFalse);
    expect(inspect({...valid, 'isMining': true}).accepted, isFalse);
    expect(inspect({...valid}..remove('isMining')).accepted, isFalse);
  });
  test('Unknown amounts are not silently converted to zero', () {
    expect(SypcReadOnlyGuard.parseUnsignedBaseUnits(null), isNull);
    expect(SypcReadOnlyGuard.parseUnsignedBaseUnits(1.5), isNull);
    expect(SypcReadOnlyGuard.parseUnsignedBaseUnits('-1'), isNull);
    expect(SypcReadOnlyGuard.parseUnsignedBaseUnits('1e6'), isNull);
    expect(SypcReadOnlyGuard.parseUnsignedBaseUnits('01'), isNull);
    expect(SypcReadOnlyGuard.parseUnsignedBaseUnits('0'), BigInt.zero);
    expect(SypcReadOnlyGuard.parseUnsignedBaseUnits('28000000000000000'),
        SypcReadOnlyPolicy.maximumBaseUnits);
    expect(SypcReadOnlyGuard.parseUnsignedBaseUnits('28000000000000001'), isNull);
  });
  test('Network activity and money movement remain disabled', () {
    expect(SypcReadOnlyPolicy.liveApiEnabled, isFalse);
    expect(SypcReadOnlyPolicy.keysEnabled, isFalse);
    expect(SypcReadOnlyPolicy.sendingEnabled, isFalse);
  });
  test('Monetary policy uses exact BigInt scale and rejects noncanonical decimals', () {
    expect(SypcReadOnlyPolicy.maximumBaseUnits.toString(), '28000000000000000');
    expect(SypcReadOnlyPolicy.baseUnitsPerSypc.toString(), '1000000000');
    expect(SypcReadOnlyGuard.parseUnsignedBaseUnits('27999999999999999'), BigInt.parse('27999999999999999'));
    for (final raw in ['', '+1', '-0', ' 1', '1 ', '1\n', '0x10', '1.0', '1e2', 1, 1.0, true, null, '9' * 79]) {
      expect(SypcReadOnlyGuard.parseUnsignedBaseUnits(raw), isNull, reason: '$raw');
    }
  });

}
