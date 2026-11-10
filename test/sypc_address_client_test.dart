import 'package:flutter_test/flutter_test.dart';
import 'package:sypc_wallet/domain/sypc_address_report.dart';
import 'package:sypc_wallet/domain/sypc_watch_only_guard.dart';
import 'package:sypc_wallet/services/sypc_address_client.dart';
import 'package:sypc_wallet/services/sypc_status_client.dart';

class _TwoGetFetcher implements SypcJsonFetcher {
  final Map<String, dynamic> status;
  final Map<String, dynamic> summary;
  final urls = <Uri>[];
  _TwoGetFetcher(this.status, this.summary);
  @override
  Future<Map<String, dynamic>> fetch(Uri uri) async {
    urls.add(uri);
    return uri.path == '/v1/status' ? status : summary;
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 9, 22, 0);
  const address = '8FYW5cms2E4xCYf44xfZm89jitXMHf83oZ3NBx3Aa99WcRkpfSwc';
  Map<String, dynamic> status() => {
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
  Map<String, dynamic> summary() => {
    'schemaVersion': 1,
    'networkId': SypcReadOnlyPolicy.networkId,
    'genesisId': SypcReadOnlyPolicy.genesisId,
    'address': address,
    'atHeight': 300,
    'bestFullBlockId': 'a' * 64,
    'observedAtUnixMs': now.millisecondsSinceEpoch,
    'confirmedBaseUnits': '27999999999999999',
    'pendingBaseUnits': '0',
    'immatureBaseUnits': '20',
    'transactions': [
      {'id': 'c' * 64, 'direction': 'incoming', 'inclusionHeight': 299,
       'amountBaseUnits': '22'},
      {'id': 'd' * 64, 'direction': 'unknown', 'inclusionHeight': null,
       'amountBaseUnits': '1'},
    ],
  };

  test('Two HTTPS GETs only, strict tip match, full-precision integer units', () async {
    final fake = _TwoGetFetcher(status(), summary());
    final result = await SypcAddressClient(fetcher: fake)
        .check('https://wallet.sypcoin.example', address, nowUtc: now);
    expect(fake.urls.map((e) => e.path).toList(), [
      '/v1/status', '/v1/addresses/$address/summary']);
    expect(fake.urls.every((u) => u.scheme == 'https' && u.userInfo.isEmpty), isTrue);
    expect(result.confirmedRaw, '27999999999999999');
    expect(result.transactions.length, 2);
    expect(result.transactions.first.inclusionHeight, 299);
  });

  test('Reject invalid candidate before contacting any server', () async {
    final fake = _TwoGetFetcher(status(), summary());
    await expectLater(SypcAddressClient(fetcher: fake).check(
      'https://wallet.sypcoin.example', 'secret phrase', nowUtc: now),
      throwsA(isA<SypcReadException>()));
    expect(fake.urls, isEmpty);
  });

  test('Wrong identity blocks second request', () async {
    final fake = _TwoGetFetcher({...status(), 'genesisId': '0' * 64}, summary());
    await expectLater(SypcAddressClient(fetcher: fake).check(
      'https://wallet.sypcoin.example', address, nowUtc: now),
      throwsA(isA<SypcReadException>()));
    expect(fake.urls.length, 1);
  });

  test('Reject different block tip even with matching genesis', () async {
    final fake = _TwoGetFetcher(status(), {...summary(), 'bestFullBlockId': 'f' * 64});
    await expectLater(SypcAddressClient(fetcher: fake).check(
      'https://wallet.sypcoin.example', address, nowUtc: now),
      throwsA(isA<SypcReadException>()));
  });

  test('Reject foreign address and any malformed amount', () async {
    for (final altered in [
      {...summary(), 'address': '4' * 50},
      {...summary(), 'confirmedBaseUnits': '1.5'},
      {...summary(), 'immatureBaseUnits': '-1'},
      {...summary(), 'pendingBaseUnits': 33},
    ]) {
      final fake = _TwoGetFetcher(status(), altered);
      await expectLater(SypcAddressClient(fetcher: fake).check(
        'https://wallet.sypcoin.example', address, nowUtc: now),
        throwsA(isA<SypcReadException>()));
    }
  });

  test('Reject duplicated transaction and impossible block heights', () async {
    for (final txs in [
      [summary()['transactions'][0], summary()['transactions'][0]],
      [{'id': 'f' * 64, 'direction': 'incoming', 'inclusionHeight': 301,
        'amountBaseUnits': '5'}],
      [{'id': 'f' * 64, 'direction': 'incoming', 'inclusionHeight': 1,
        'amountBaseUnits': 'bad'}],
    ]) {
      final fake = _TwoGetFetcher(status(), {...summary(), 'transactions': txs});
      await expectLater(SypcAddressClient(fetcher: fake).check(
        'https://wallet.sypcoin.example', address, nowUtc: now),
        throwsA(isA<SypcReadException>()));
    }
  });

  test('Reject stale summary, too many movements and rogue miner status', () async {
    final stale = _TwoGetFetcher(status(), {...summary(),
      'observedAtUnixMs': now.subtract(const Duration(minutes: 20)).millisecondsSinceEpoch});
    await expectLater(SypcAddressClient(fetcher: stale).check(
      'https://wallet.sypcoin.example', address, nowUtc: now),
      throwsA(isA<SypcReadException>()));
    final huge = _TwoGetFetcher(status(), {...summary(),
      'transactions': List.generate(SypcAddressReportGuard.maxTransactions+1, (n) =>
        {'id': n.toRadixString(16).padLeft(64,'0'),
          'direction': 'unknown', 'inclusionHeight': null,
          'amountBaseUnits': '1'})});
    await expectLater(SypcAddressClient(fetcher: huge).check(
      'https://wallet.sypcoin.example', address, nowUtc: now),
      throwsA(isA<SypcReadException>()));
    final miner = _TwoGetFetcher({...status(), 'isMining': true}, summary());
    await expectLater(SypcAddressClient(fetcher: miner).check(
      'https://wallet.sypcoin.example', address, nowUtc: now),
      throwsA(isA<SypcReadException>()));
    expect(miner.urls.length, 1);
  });
  test('Supply cap applies to every balance category and transaction amount', () async {
    for (final field in ['confirmedBaseUnits', 'pendingBaseUnits', 'immatureBaseUnits']) {
      for (final invalid in ['-1', '01', '1e9', '28000000000000001', '9' * 78]) {
        final fake = _TwoGetFetcher(status(), {...summary(), field: invalid});
        await expectLater(SypcAddressClient(fetcher: fake).check(
          'https://wallet.sypcoin.example', address, nowUtc: now),
          throwsA(isA<SypcReadException>().having((e) => e.code, 'code', 'ADDRESS_AMOUNT_INVALID')));
      }
    }
    for (final amount in ['-1', '0.5', '28000000000000001']) {
      final fake = _TwoGetFetcher(status(), {...summary(), 'transactions': [
        {'id': 'e' * 64, 'direction': 'incoming', 'inclusionHeight': 299, 'amountBaseUnits': amount}]});
      await expectLater(SypcAddressClient(fetcher: fake).check(
        'https://wallet.sypcoin.example', address, nowUtc: now),
        throwsA(isA<SypcReadException>().having((e) => e.code, 'code', 'ADDRESS_AMOUNT_INVALID')));
    }
  });
  test('Overlapping categories and historical movements are not summed as supply', () async {
    const maximum = '28000000000000000';
    final fake = _TwoGetFetcher(status(), {...summary(),
      'confirmedBaseUnits': maximum, 'pendingBaseUnits': maximum,
      'immatureBaseUnits': maximum, 'transactions': [
        {'id': 'e' * 64, 'direction': 'incoming', 'inclusionHeight': 299, 'amountBaseUnits': maximum},
        {'id': 'f' * 64, 'direction': 'outgoing', 'inclusionHeight': 298, 'amountBaseUnits': maximum}]});
    final report = await SypcAddressClient(fetcher: fake).check(
      'https://wallet.sypcoin.example', address, nowUtc: now);
    expect(report.confirmedBaseUnits, SypcReadOnlyPolicy.maximumBaseUnits);
    expect(report.transactions.length, 2);
  });

  test('Direct report guard rejects foreign and legacy addresses even if server repeats them', () {
    final tip = SypcReadOnlyGuard.inspect(status(), nowUtc: now).tip!;
    for (final bad in ['3AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      '9fSgJ7BmUxBQJ454prQDQ7fQMBkXPLaAmDnimgTtjym6FYPHjAV',
      '1BoatSLRHtKNngkdXEeobR76b53LETtpyT']) {
      expect(() => SypcAddressReportGuard.inspect({...summary(), 'address': bad},
        requestedAddress: bad, tip: tip, nowUtc: now),
        throwsA(isA<SypcReadException>().having((e) => e.code, 'code', 'ADDRESS_MISMATCH')));
    }
  });

}
