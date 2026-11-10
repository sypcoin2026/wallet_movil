import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sypc_wallet/domain/sypc_watch_book.dart';

void main() {
  const address = '8FYW5cms2E4xCYf44xfZm89jitXMHf83oZ3NBx3Aa99WcRkpfSwc';
  final book = const SypcWatchBook().add(address: address, label: 'Minera')
    .withOrigin('https://api.sypcoin.example');

  test('Offline backup restores entries, selection and HTTPS origin', () {
    final copy = book.encode();
    final loaded = SypcWatchBook.decode(copy);
    expect(loaded.entries.single.label, 'Minera');
    expect(loaded.activeAddress, address);
    expect(loaded.apiOrigin, 'https://api.sypcoin.example');
    expect(copy.contains('privateKey'), isFalse);
    expect(copy.contains('mnemonic'), isFalse);
  });

  test('Backup refuses foreign genesis, invalid JSON and duplicate addresses', () {
    final raw = jsonDecode(book.encode()) as Map<String, dynamic>;
    for (final modified in [
      {...raw, 'genesisId': '0'*64},
      {...raw, 'schemaVersion': 999},
      {...raw, 'entries': [...(raw['entries'] as List), ...(raw['entries'] as List)]},
      {...raw, 'selectedAddress': '4'*60},
    ]) {
      expect(() => SypcWatchBook.decode(jsonEncode(modified)), throwsFormatException);
    }
    expect(() => SypcWatchBook.decode('this is not json'), throwsFormatException);
  });
}
