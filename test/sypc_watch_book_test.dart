import 'package:flutter_test/flutter_test.dart';
import 'package:sypc_wallet/domain/sypc_watch_book.dart';
import 'package:sypc_wallet/services/sypc_watch_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const first = '8FYW5cms2E4xCYf44xfZm89jitXMHf83oZ3NBx3Aa99WcRkpfSwc';
const second = '8FY4Yd2wrQTzCrxcfogZqoBRABgKRyG8oPkxijAKegpMFFF6ME6P';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Real local CRUD: add, choose, rename and remove', () {
    final firstBook = const SypcWatchBook().add(address: first, label: 'Minera');
    final both = firstBook.add(address: second, label: 'Observada 2');
    expect(both.entries.length, 2);
    expect(both.activeAddress, second);
    final chosen = both.select(first);
    expect(chosen.activeAddress, first);
    final renamed = chosen.rename(first, 'Prueba local');
    expect(renamed.entries.first.label, 'Prueba local');
    final removed = renamed.remove(first);
    expect(removed.entries.length, 1);
    expect(removed.activeAddress, second);
    expect(removed.entries.first.address, second);
  });

  test('Reject mnemonics, unbounded input, duplicates and invalid addresses', () {
    final book = const SypcWatchBook().add(address: first, label: 'Minera');
    expect(() => book.add(address: first, label: 'Duplicada'), throwsFormatException);
    expect(() => book.add(address: 'palabra palabra palabra palabra', label: 'Seed'), throwsFormatException);
    expect(() => book.add(address: '0' * 51, label: 'Base58 invalido'), throwsFormatException);
    expect(() => book.add(address: 'ABC', label: 'Corta'), throwsFormatException);
    expect(() => book.rename(first, 'x' * 49), throwsFormatException);
    expect(() => book.select('no existe'), throwsFormatException);
  });

  test('JSON is pinned to genesis, not usable across networks', () {
    final book = const SypcWatchBook().add(address: first, label: 'Prueba');
    final encoded = book.encode();
    expect(SypcWatchBook.decode(encoded).activeAddress, first);
    expect(() => SypcWatchBook.decode(encoded.replaceFirst('SypPrivateV30', 'MainNet')),
        throwsFormatException);
    expect(() => SypcWatchBook.decode('{"bad":true}'), throwsFormatException);
    expect(() => SypcWatchBook.decode('{'), throwsFormatException);
  });

  test('Persistence survives second load, without mock balances or secrets', () async {
    SharedPreferences.setMockInitialValues({});
    final book = const SypcWatchBook()
        .add(address: first, label: 'Receptor')
        .withOrigin('https://api.sypcoin.example');
    await SypcWatchStore.save(book);
    final restored = await SypcWatchStore.load();
    expect(restored.activeAddress, first);
    expect(restored.entries.single.label, 'Receptor');
    expect(restored.apiOrigin, 'https://api.sypcoin.example');
    expect(restored.encode().contains('seed'), isFalse);
  });

  test('Corrupt persisted state fails closed and is not silently reset', () async {
    SharedPreferences.setMockInitialValues({SypcWatchStore.key: '{bad json'});
    await expectLater(SypcWatchStore.load(), throwsFormatException);
  });

  test('Remove last address does not invent a replacement', () {
    final book = const SypcWatchBook().add(address: first, label: 'Uno');
    final cleared = book.remove(first);
    expect(cleared.activeAddress, isEmpty);
    expect(cleared.entries, isEmpty);
  });
}
