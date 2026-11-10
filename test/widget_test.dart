import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sypc_wallet/domain/sypc_watch_book.dart';
import 'package:sypc_wallet/pages/watchlist_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sypc_wallet/main.dart';
import 'package:sypc_wallet/splash/sypc_splash_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> openWallet(WidgetTester tester) async {
  await tester.pumpWidget(const SypcWalletApp());
  expect(find.byType(SypcSplashPage), findsOneWidget);
  await tester.pump();
  for (var i = 0; i < 10 && find.byType(SypcSplashPage).evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(find.byType(SypcSplashPage), findsNothing,
      reason: 'El splash debe terminar despues de la animacion y pausa');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Logo starts in the splash and opens wallet', (tester) async {
    await openWallet(tester);
    expect(find.text('SYPC Wallet'), findsOneWidget);
  });

  testWidgets('No real or invented balance is shown', (tester) async {
    await openWallet(tester);
    expect(find.text('TESTNET · V0.6.1'), findsOneWidget);
    expect(find.text('— SYPC'), findsOneWidget);
    expect(find.text('Sin datos de la blockchain'), findsOneWidget);
  });

  testWidgets('Send is accessible but transactions are disabled', (tester) async {
    await openWallet(tester);
    await tester.scrollUntilVisible(
      find.text('Enviar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(find.text('Envios bloqueados en v0.6'), findsOneWidget);
    final sendButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Envios bloqueados en v0.6'),
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('SecureTrade cannot open or lock funds', (tester) async {
    await openWallet(tester);
    await tester.tap(find.text('Proteger'));
    await tester.pumpAndSettle();
    expect(find.text('SOLO DISENO · NO OPERA CON DINERO REAL'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Crear operacion · no disponible'), 240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Crear operacion · no disponible'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Fiat mode explicitly requires external verification', (tester) async {
    await openWallet(tester);
    await tester.tap(find.text('Proteger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SYPC / EUR'));
    await tester.pumpAndSettle();
    expect(find.textContaining('pago bancario'), findsOneWidget);
  });

  testWidgets('Internet setup exists, but never claims a verified balance', (tester) async {
    await openWallet(tester);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Servidor HTTPS · solo lectura'), 250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Servidor HTTPS · solo lectura'), findsOneWidget);
    expect(find.text('Consultar HTTPS'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Consultar HTTPS'),
    );
    expect(button.onPressed, isNull, reason: 'No server configured by default');
  });

  testWidgets('Settings states that secrets must never be entered', (tester) async {
    await openWallet(tester);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('NUNCA introduzcas'), findsOneWidget);
  });

  testWidgets('Public imported address is shown as an offline QR', (tester) async {
    final testAddress = '8FYW5cms2E4xCYf44xfZm89jitXMHf83oZ3NBx3Aa99WcRkpfSwc';
    final raw = '{"schemaVersion":1,"networkId":"SypPrivateV30",'
      '"genesisId":"8b404d4c2f9c394e36faf7992c92bb670b3bf7d4e14c8e83f9acb323d67d030d",'
      '"selectedAddress":"$testAddress","apiOrigin":"",'
      '"entries":[{"label":"Prueba","address":"$testAddress"}]}';
    SharedPreferences.setMockInitialValues({'sypc_watch_book_v1': raw});
    await openWallet(tester);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Recibir').last);
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('QR de direccion observada'), findsOneWidget);
  });

testWidgets('v0.6 activity never offers a remote query without address and server', (tester) async {
  SharedPreferences.setMockInitialValues({});
  await openWallet(tester);
  await tester.tap(find.text('Actividad').last);
  await tester.pumpAndSettle();
  expect(find.textContaining('NO VERIFICADOS EN CADENA'), findsOneWidget);
  expect(find.text('Sin historial remoto aceptado'), findsOneWidget);
  final button = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Consultar saldos e historial'));
  expect(button.onPressed, isNull);
});

  testWidgets('Persisted legacy address stays visible, requires review and has no QR', (tester) async {
    const legacy = '3AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    final raw = jsonEncode({
      'schemaVersion': 1, 'networkId': 'SypPrivateV30',
      'genesisId': '8b404d4c2f9c394e36faf7992c92bb670b3bf7d4e14c8e83f9acb323d67d030d',
      'selectedAddress': legacy, 'apiOrigin': 'https://wallet.sypcoin.example',
      'entries': [{'label': 'Minera antigua', 'address': legacy}],
    });
    SharedPreferences.setMockInitialValues({'sypc_watch_book_v1': raw});
    await openWallet(tester);
    await tester.tap(find.text('Recibir').last);
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('REQUIERE REVISION'), findsOneWidget);
    expect(find.text(legacy), findsOneWidget);
    await tester.tap(find.text('Actividad').last);
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Consultar saldos e historial'));
    expect(button.onPressed, isNull);
    expect((await SharedPreferences.getInstance()).getString('sypc_watch_book_v1'), raw);
  });
  testWidgets('Long P2S keeps text and script warning when QR capacity is exceeded', (tester) async {
    final address = File('test/fixtures/native_address_vectors.tsv').readAsLinesSync()
      .map((r) => r.split('\t')).singleWhere((r) => r[0] == 'native_long_p2s_120')[2];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReceivePage(
      publicAddress: address, onCopy: () {}, onAddAddress: () {}))));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('script NO validado'), findsOneWidget);
    expect(find.text('Direccion larga · copia el texto (sin QR)'), findsOneWidget);
    expect(find.text(address), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Watchlist displays legacy review without losing its label', (tester) async {
    const book = SypcWatchBook(entries: [SypcWatchEntry(label: 'Minera antigua',
      address: '3AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')]);
    await tester.pumpWidget(MaterialApp(home: SypcWatchlistPage(book: book,
      onSelect: (_) async => true, onDelete: (_) async => true,
      onRename: (address, label) async => true)));
    expect(find.text('Minera antigua'), findsOneWidget);
    expect(find.textContaining('REQUIERE REVISION'), findsOneWidget);
  });

}
