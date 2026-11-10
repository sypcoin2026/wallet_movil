import 'package:flutter_test/flutter_test.dart';
import 'package:sypc_wallet/domain/sypc_watch_only_guard.dart';
import 'package:sypc_wallet/services/sypc_status_client.dart';

class _FakeFetcher implements SypcJsonFetcher {
  final Map<String, dynamic> payload;
  Uri? requested;
  _FakeFetcher(this.payload);

  @override
  Future<Map<String, dynamic>> fetch(Uri url) async {
    requested = url;
    return payload;
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 9, 20, 0);
  Map<String, dynamic> validPayload() => {
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

  test('Only public HTTPS origins are accepted', () {
    expect(SypcEndpointPolicy.statusUri('https://api.sypcoin.example').toString(),
        'https://api.sypcoin.example/v1/status');
    for (final endpoint in [
      'http://api.sypcoin.example',
      'https://127.0.0.1',
      'https://192.168.1.21:9053',
      'https://localhost',
      'https://api.local',
      'https://user:pass@api.sypcoin.example',
      'https://api.sypcoin.example/management',
      'https://api.sypcoin.example?key=secret',
      'https://api.sypcoin.example:8443',
    ]) {
      expect(() => SypcEndpointPolicy.statusUri(endpoint),
          throwsA(isA<SypcReadException>()), reason: endpoint);
    }
  });

  test('Read client requests only /v1/status and validates claimed identity', () async {
    final fake = _FakeFetcher(validPayload());
    final result = await SypcStatusClient(fetcher: fake)
        .check('https://api.sypcoin.example/', nowUtc: now);
    expect(fake.requested?.path, '/v1/status');
    expect(fake.requested?.scheme, 'https');
    expect(result.accepted, isTrue);
    expect(result.tip?.fullHeight, 300);
  });

  test('No API call occurs on an unsafe origin', () async {
    final fake = _FakeFetcher(validPayload());
    await expectLater(
      SypcStatusClient(fetcher: fake).check('http://192.168.1.21:9053'),
      throwsA(isA<SypcReadException>()),
    );
    expect(fake.requested, isNull);
  });

  test('A foreign network cannot be shown as a valid report', () async {
    final fake = _FakeFetcher({...validPayload(), 'genesisId': '0' * 64});
    final result = await SypcStatusClient(fetcher: fake)
        .check('https://api.sypcoin.example', nowUtc: now);
    expect(result.accepted, isFalse);
    expect(result.rejectionCode, 'GENESIS_MISMATCH');
  });
}
