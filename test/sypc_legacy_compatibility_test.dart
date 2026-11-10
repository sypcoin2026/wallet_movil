import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sypc_wallet/domain/sypc_watch_book.dart';
import 'package:sypc_wallet/domain/sypc_watch_only_guard.dart';
import 'package:sypc_wallet/services/sypc_watch_store.dart';
import 'package:sypc_wallet/services/sypc_address_client.dart';
import 'package:sypc_wallet/services/sypc_status_client.dart';

const _legacy = '3AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _minera = '8FYW5cms2E4xCYf44xfZm89jitXMHf83oZ3NBx3Aa99WcRkpfSwc';
const _solidaridad = '8FY4Yd2wrQTzCrxcfogZqoBRABgKRyG8oPkxijAKegpMFFF6ME6P';
const _desarrollo = '8FXeQHkEXaRdfhyux2MPnYR4Lgr3fHRwuQBqo3hrgcyeScRcUgrx';
String _oldBackup() => jsonEncode({
      'schemaVersion': 1,
      'networkId': SypcReadOnlyPolicy.networkId,
      'genesisId': SypcReadOnlyPolicy.genesisId,
      'apiOrigin': '',
      'selectedAddress': _legacy,
      'entries': [
        {'label': 'Minera', 'address': _minera},
        {'label': 'Solidaridad', 'address': _solidaridad},
        {'label': 'Desarrollo', 'address': _desarrollo},
        {'label': 'Antigua', 'address': _legacy},
      ],
    });

class _NeverFetcher implements SypcJsonFetcher {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> fetch(Uri url) async {
    calls++;
    throw StateError('Invalid addresses must never reach transport');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'v0.6 backup preserves legacy selection, labels and explicit review state',
      () {
    final book = SypcWatchBook.decode(_oldBackup());
    expect(book.activeAddress, _legacy);
    expect(book.entries.map((e) => e.label),
        ['Minera', 'Solidaridad', 'Desarrollo', 'Antigua']);
    expect(book.entries.where((e) => e.needsReview).single.address, _legacy);
    expect(book.entries.last.validation.label, contains('REQUIERE REVISION'));
    expect(SypcWatchBook.decode(book.encode()).encode(), book.encode());
    expect(() => const SypcWatchBook().add(address: _legacy, label: 'Nueva'),
        throwsFormatException);
    expect(
        book
            .rename(_legacy, 'Revisar')
            .select(_legacy)
            .entries
            .last
            .needsReview,
        isTrue);
  });
  test(
      'Loading and saving preserves old invalid entries without rewriting on load',
      () async {
    final raw = _oldBackup();
    SharedPreferences.setMockInitialValues({SypcWatchStore.key: raw});
    final loaded = await SypcWatchStore.load();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SypcWatchStore.key), raw);
    await SypcWatchStore.save(loaded.rename(_legacy, 'Antigua conservada'));
    final reloaded = await SypcWatchStore.load();
    expect(reloaded.entries.length, 4);
    expect(reloaded.entries.last.address, _legacy);
    expect(reloaded.entries.last.label, 'Antigua conservada');
    expect(reloaded.entries.last.needsReview, isTrue);
    expect(reloaded.activeAddress, _legacy);
  });
  test('Legacy entries cannot bypass remote query validation', () async {
    final fake = _NeverFetcher();
    await expectLater(
        SypcAddressClient(fetcher: fake)
            .check('https://wallet.sypcoin.example', _legacy),
        throwsA(isA<SypcReadException>()));
    expect(fake.calls, 0);
  });
  test('Long P2S survives add, save, export and import with its label',
      () async {
    final long = File('test/fixtures/native_address_vectors.tsv')
        .readAsLinesSync()
        .map((r) => r.split('\t'))
        .singleWhere((r) => r[0] == 'native_long_p2s_120')[2];
    SharedPreferences.setMockInitialValues({});
    final book =
        const SypcWatchBook().add(address: long, label: 'Contrato largo');
    await SypcWatchStore.save(book);
    final loaded = await SypcWatchStore.load();
    expect(loaded.entries.single.label, 'Contrato largo');
    expect(loaded.activeAddress, long);
    expect(loaded.entries.single.validation.needsScriptReview, isTrue);
    expect(SypcWatchBook.decode(loaded.encode()).activeAddress, long);
  });
  test(
      'Non-legacy malformed backups fail explicitly rather than dropping entries',
      () {
    final data = jsonDecode(_oldBackup()) as Map<String, dynamic>;
    data['entries'][3]['address'] = 'not an address';
    expect(() => SypcWatchBook.decode(jsonEncode(data)), throwsFormatException);
    expect(
        () => SypcWatchBook.decode(' ' * (SypcWatchBook.maxBackupLength + 1)),
        throwsFormatException);
  });
}
