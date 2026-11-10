import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'domain/sypc_watch_book.dart';
import 'domain/sypc_address_report.dart';
import 'domain/sypc_address_validator.dart';
import 'services/sypc_address_client.dart';
import 'services/sypc_watch_store.dart';
import 'pages/watchlist_page.dart';
import 'domain/sypc_models.dart';
import 'domain/sypc_watch_only_guard.dart';
import 'services/sypc_status_client.dart';
import 'splash/sypc_splash_page.dart';

void main() => runApp(const SypcWalletApp());

const _background = Color(0xFF031123);
const _panel = Color(0xFF081C33);
const _panelRaised = Color(0xFF11304B);
const _purple = Color(0xFF18CFFF);
const _mint = Color(0xFF41DBB1);
const _gold = Color(0xFFBDEFFF);
const _soft = Color(0xFFA8C1D4);
const _warning = Color(0xFFFFCF81);

class SypcWalletApp extends StatelessWidget {
  const SypcWalletApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SYPC Wallet',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _background,
          colorScheme: const ColorScheme.dark(
            primary: _purple,
            secondary: _mint,
            surface: _panel,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: _background,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _panelRaised,
            hintStyle: const TextStyle(color: _soft),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        home: const _SplashGate(),
      );
}

class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _showWallet = false;

  @override
  Widget build(BuildContext context) => _showWallet
      ? const WalletShell()
      : SypcSplashPage(
          onFinished: () {
            if (mounted) setState(() => _showWallet = true);
          },
        );
}

class WalletShell extends StatefulWidget {
  const WalletShell({super.key});

  @override
  State<WalletShell> createState() => _WalletShellState();
}

class _WalletShellState extends State<WalletShell> {
  int _tab = 0;
  String _publicAddress = '';
  SypcWatchBook _book = const SypcWatchBook();
  bool _localStorageReady = false;
  bool _storageInvalid = false;
  String _apiOrigin = '';
  String _connectionMessage = 'Servicio HTTPS sin configurar';
  SypcReadOnlyTip? _reportedTip;
  bool _checking = false;
  int _requestSerial = 0;
  final SypcStatusClient _statusClient = SypcStatusClient();
  final SypcAddressClient _addressClient = SypcAddressClient();
  SypcAddressReport? _addressReport;
  String _addressReadMessage = 'Ningun saldo ni historial consultado';
  bool _readingAddress = false;
  int _addressRequestSerial = 0;

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLocalBook();
  }

  Future<void> _loadLocalBook() async {
    try {
      final loaded = await SypcWatchStore.load();
      if (!mounted) return;
      setState(() {
        _book = loaded;
        _publicAddress = loaded.activeAddress;
        _apiOrigin = loaded.apiOrigin;
        _localStorageReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localStorageReady = true;
        _storageInvalid = true;
      });
      _showToast('Datos locales invalidos: no se han sobrescrito.');
    }
  }

  Future<bool> _persistBook(SypcWatchBook next) async {
    if (!_localStorageReady || _storageInvalid) {
      _showToast('Guardado bloqueado: revisa los datos locales.');
      return false;
    }
    try {
      await SypcWatchStore.save(next);
      if (!mounted) return false;
      setState(() {
        _book = next;
        _publicAddress = next.activeAddress;
        _apiOrigin = next.apiOrigin;
        _reportedTip = null;
        _requestSerial++;
        _checking = false;
        _addressRequestSerial++;
        _readingAddress = false;
        _addressReport = null;
        _addressReadMessage = 'Direccion o servidor cambiado. Actualiza la consulta.';
      });
      return true;
    } catch (_) {
      if (mounted) _showToast('No se han podido guardar los datos locales.');
      return false;
    }
  }

  Future<void> _savePublicAddress(String raw) async {
    final value = raw.trim();
    try {
      final updated = _book.add(
        address: value, label: 'Observada ${_book.entries.length + 1}');
      if (await _persistBook(updated) && mounted) {
        _showToast('Direccion PUBLICA guardada. No implica control de fondos.');
      }
    } on FormatException catch (error) {
      _showToast(error.message);
    }
  }

  Future<void> _saveApiOrigin(String raw) async {
    try {
      SypcEndpointPolicy.statusUri(raw);
    } on SypcReadException catch (error) {
      _showToast(sypcReadErrorLabel(error.code));
      return;
    }
    final saved = await _persistBook(_book.withOrigin(raw));
    if (!mounted || !saved) return;
    setState(() => _connectionMessage = 'Servidor HTTPS guardado localmente. No verificado.');
    _showToast('Servidor HTTPS guardado para proximas sesiones.');
  }

  Future<bool> _selectWatched(String address) async {
    try { return await _persistBook(_book.select(address)); }
    on FormatException catch (e) { _showToast(e.message); return false; }
  }

  Future<bool> _deleteWatched(String address) async {
    try { return await _persistBook(_book.remove(address)); }
    on FormatException catch (e) { _showToast(e.message); return false; }
  }

  Future<bool> _renameWatched(String address, String label) async {
    try { return await _persistBook(_book.rename(address, label)); }
    on FormatException catch (e) { _showToast(e.message); return false; }
  }

  void _openWatched() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => SypcWatchlistPage(
      book: _book,
      onSelect: (value) async {
        final result = await _selectWatched(value);
        if (result && mounted) Navigator.of(context).pop();
        return result;
      },
      onDelete: (value) async {
        final result = await _deleteWatched(value);
        if (result && mounted) Navigator.of(context).pop();
        return result;
      },
      onRename: (address, label) async {
        final result = await _renameWatched(address, label);
        if (result && mounted) Navigator.of(context).pop();
        return result;
      },
    )),
  );

  Future<void> _checkApiOrigin() async {
    if (_checking || _apiOrigin.isEmpty) return;
    final serial = ++_requestSerial;
    setState(() {
      _checking = true;
      _reportedTip = null;
      _connectionMessage = 'Consultando informe HTTPS...';
    });
    try {
      final inspection = await _statusClient.check(_apiOrigin);
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _checking = false;
        _reportedTip = inspection.tip;
        _connectionMessage = inspection.accepted
            ? 'Informe HTTPS aceptado estructuralmente; SIN prueba de consenso.'
            : sypcReadErrorLabel(inspection.rejectionCode ?? 'UNKNOWN');
      });
    } on SypcReadException catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _checking = false;
        _reportedTip = null;
        _connectionMessage = sypcReadErrorLabel(error.code);
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _checking = false;
        _reportedTip = null;
        _connectionMessage = 'Consulta rechazada. No hay datos verificados.';
      });
    }
  }

  /// Manual export only. The backup contains PUBLIC watchlist metadata,
  /// including the HTTPS origin, but NEVER keys or signing material.
  Future<void> _exportPublicBackup() async {
    if (!_localStorageReady || _storageInvalid) {
      _showToast('Datos locales no disponibles. Exportacion bloqueada.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _book.encode()));
    if (mounted) _showToast('Copia publica en el portapapeles. Guardala en lugar privado.');
  }

  Future<void> _importPublicBackup() async {
    if (!_localStorageReady || _storageInvalid) {
      _showToast('No se puede importar sobre datos locales invalidos.');
      return;
    }
    final controller = TextEditingController();
    final text = await showDialog<String>(context: context, builder: (ctx) =>
      AlertDialog(
        title: const Text('Restaurar lista PUBLICA'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pega un respaldo exportado por SYPC Wallet. Reemplazara la lista '
              'local y el servidor HTTPS. NUNCA pegues semillas ni contrasenas.'),
            const SizedBox(height: 10),
            TextField(controller: controller, maxLines: 6, minLines: 3,
              maxLength: SypcWatchBook.maxBackupLength, autocorrect: false, enableSuggestions: false,
              decoration: const InputDecoration(hintText: 'JSON de copia publica')),
          ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Revisar')),
        ],
      ));
    controller.dispose();
    if (text == null || !mounted) return;
    SypcWatchBook restored;
    try {
      restored = SypcWatchBook.decode(text);
    } catch (_) {
      _showToast('Respaldo incompatible, alterado o mal formado. Sin cambios.');
      return;
    }
    final confirm = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(title: const Text('Confirmar restauracion'),
        content: Text('Se sustituiran ${_book.entries.length} direcciones por '
          '${restored.entries.length} del respaldo PUBLICO. '
          '${restored.entries.where((e) => e.needsReview).length} requieren revision. No mueve monedas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar')),
        ]));
    if (confirm == true && mounted) {
      if (await _persistBook(restored) && mounted) {
        _showToast('Libreta publica restaurada correctamente.');
      }
    }
  }

  Future<void> _checkAddressReport() async {
    if (_readingAddress || !SypcWatchEntry.isPublicCandidate(_publicAddress) || _apiOrigin.isEmpty) return;
    final serial = ++_addressRequestSerial;
    final address = _publicAddress;
    final origin = _apiOrigin;
    setState(() {
      _readingAddress = true;
      _addressReport = null;
      _addressReadMessage = 'Consultando servidor HTTPS...';
    });
    try {
      final report = await _addressClient.check(origin, address);
      if (!mounted || serial != _addressRequestSerial) return;
      setState(() {
        _readingAddress = false;
        _addressReport = report;
        _addressReadMessage = 'Informe remoto recibido, NO verificado por consenso.';
      });
    } on SypcReadException catch (error) {
      if (!mounted || serial != _addressRequestSerial) return;
      setState(() {
        _readingAddress = false;
        _addressReport = null;
        _addressReadMessage = sypcReadErrorLabel(error.code);
      });
    } catch (_) {
      if (!mounted || serial != _addressRequestSerial) return;
      setState(() {
        _readingAddress = false;
        _addressReport = null;
        _addressReadMessage = 'Consulta rechazada. No se presenta ningun saldo.';
      });
    }
  }

  void _copyAddress() {
    if (_publicAddress.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _publicAddress));
    _showToast('Texto de direccion publica copiado. Comprueba la red antes de utilizarlo.');
  }

  void _showSend() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SendPage()),
      );

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        publicAddress: _publicAddress,
        reportedTip: _reportedTip,
        connectionMessage: _connectionMessage,
        onReceive: () => setState(() => _tab = 1),
        onSend: _showSend,
        onSecureTrade: () => setState(() => _tab = 2),
      ),
      ReceivePage(
        publicAddress: _publicAddress,
        onCopy: _copyAddress,
        onAddAddress: () => setState(() => _tab = 4),
      ),
      const SecureTradePage(),
      ActivityPage(
        address: _publicAddress,
        apiOrigin: _apiOrigin,
        report: _addressReport,
        reading: _readingAddress,
        message: _addressReadMessage,
        onRefresh: _checkAddressReport,
      ),
      SettingsPage(
        publicAddress: _publicAddress,
        onSaveAddress: _savePublicAddress,
        onManageWatch: _openWatched,
        onExportBook: _exportPublicBackup,
        onImportBook: _importPublicBackup,
        watchCount: _book.entries.length,
        apiOrigin: _apiOrigin,
        connectionMessage: _connectionMessage,
        reportedTip: _reportedTip,
        checking: _checking,
        onSaveApiOrigin: _saveApiOrigin,
        onCheckApi: _checkApiOrigin,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 19,
        title: const Row(children: [
          _Logo(),
          SizedBox(width: 10),
          Text('SYPC Wallet',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ]),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: Center(child: _NetworkChip()),
          ),
        ],
      ),
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: _panel,
        height: 75,
        selectedIndex: _tab,
        indicatorColor: _panelRaised,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Inicio',
          ),
          NavigationDestination(icon: Icon(Icons.south_west), label: 'Recibir'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Proteger'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Actividad'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/branding/sypcoin_logo_circular.png',
        height: 38,
        width: 38,
        fit: BoxFit.contain,
        semanticLabel: 'SYPcoin, dragon S oficial',
      );
}

class _NetworkChip extends StatelessWidget {
  const _NetworkChip();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _purple.withValues(alpha: 0.15),
        ),
        child: const Text('TESTNET · V0.6.1',
            style: TextStyle(
              color: Color(0xFFDBC6FF),
              fontWeight: FontWeight.bold,
              fontSize: 10,
            )),
      );
}

class _WalletCard extends StatelessWidget {
  final Widget child;
  const _WalletCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: child,
      );
}

class _PageHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PageHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: _soft, height: 1.4)),
        ],
      );
}

class HomePage extends StatelessWidget {
  final String publicAddress;
  final SypcReadOnlyTip? reportedTip;
  final String connectionMessage;
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback onSecureTrade;

  const HomePage({
    super.key,
    required this.publicAddress,
    required this.reportedTip,
    required this.connectionMessage,
    required this.onReceive,
    required this.onSend,
    required this.onSecureTrade,
  });

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(19),
        children: [
          const _PageHeading(
              title: 'Mi cartera',
              subtitle: 'Privada por diseno · testnet experimental'),
          const SizedBox(height: 21),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF073F70), Color(0xFF081C33)],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: _purple.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      color: _gold, size: 18),
                  SizedBox(width: 9),
                  Text('SALDO TOTAL',
                      style: TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontSize: 12)),
                ]),
                const SizedBox(height: 19),
                Row(
                  children: [
                    const Expanded(
                      child: Text('— SYPC',
                        style: TextStyle(fontSize: 37, fontWeight: FontWeight.w900)),
                    ),
                    Image.asset('assets/branding/sypcoin_logo_circular.png',
                        width: 65, height: 65, fit: BoxFit.contain),
                  ],
                ),
                const SizedBox(height: 7),
                const Text('Sin datos de la blockchain',
                    style: TextStyle(color: _soft)),
                const SizedBox(height: 21),
                const Divider(color: Color(0xFF25638B)),
                const SizedBox(height: 11),
                Row(children: [
                  const Icon(Icons.cloud_off_rounded, color: _warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(connectionMessage,
                        style: const TextStyle(color: _warning, fontSize: 13)),
                  ),
                ]),
              ],
            ),
          ),
          if (reportedTip != null) ...[
            const SizedBox(height: 14),
            _WalletCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('INFORME REMOTO · NO VERIFICADO',
                  style: TextStyle(color: _warning, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Altura declarada: ${reportedTip!.fullHeight}',
                  style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text('Fecha UTC: ${reportedTip!.observedAtUtc.toIso8601String()}',
                  style: const TextStyle(color: _soft, fontSize: 12)),
                const SizedBox(height: 8),
                const Text('No se muestran saldos: falta prueba criptografica independiente.',
                  style: TextStyle(color: _soft)),
              ],
            )),
          ],
          const SizedBox(height: 16),
          const _WalletCard(
            child: Column(children: [
              _BalanceLine(
                  icon: Icons.verified_outlined, title: 'Disponible', value: '—'),
              Divider(height: 28),
              _BalanceLine(
                  icon: Icons.schedule,
                  title: 'Pendiente de confirmar',
                  value: '—'),
              Divider(height: 28),
              _BalanceLine(
                  icon: Icons.lock_clock_outlined,
                  title: 'Recompensas inmaduras',
                  value: '—'),
            ]),
          ),
          const SizedBox(height: 17),
          Row(children: [
            Expanded(
              child: _ActionTile(
                  icon: Icons.north_east,
                  label: 'Enviar',
                  onTap: onSend),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                  icon: Icons.south_west,
                  label: 'Recibir',
                  onTap: onReceive),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                  icon: Icons.shield_outlined,
                  label: 'SecureTrade',
                  onTap: onSecureTrade),
            ),
          ]),
          const SizedBox(height: 18),
          _WalletCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.visibility_outlined, color: _mint),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Modo solo lectura',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 7),
                        Text(
                          publicAddress.isEmpty
                              ? 'Aun no has introducido una direccion publica. No se generan claves ni saldos ficticios.'
                              : 'Direccion publica guardada localmente. No acredita propiedad ni fondos; consulta de cadena pendiente.',
                          style: const TextStyle(color: _soft, height: 1.45),
                        ),
                      ]),
                ),
              ],
            ),
          ),
        ],
      );
}

class _BalanceLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _BalanceLine(
      {required this.icon, required this.title, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: _soft, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title,
                style: const TextStyle(color: _soft, fontSize: 13))),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ]);
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: _panel,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 3),
            child: Column(children: [
              Icon(icon, color: _purple, size: 26),
              const SizedBox(height: 9),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );
}

class ReceivePage extends StatelessWidget {
  // Maximum ASCII byte payload for QR version 40 at the widget's default L level.
  static const int _maxQrCharacters = 2953;
  final String publicAddress;
  final VoidCallback onCopy;
  final VoidCallback onAddAddress;

  const ReceivePage({
    super.key,
    required this.publicAddress,
    required this.onCopy,
    required this.onAddAddress,
  });

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(19),
        children: [
          const _PageHeading(
            title: 'Recibir SYPC',
            subtitle: 'Direccion de consulta · no validada en cadena',
          ),
          const SizedBox(height: 22),
          _WalletCard(
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18)),
                child: !SypcWatchEntry.isPublicCandidate(publicAddress) || publicAddress.length > _maxQrCharacters
                    ? const SizedBox(height: 220, width: 220,
                        child: Icon(Icons.qr_code_2_rounded, size: 88, color: Colors.black54))
                    : QrImageView(data: publicAddress, size: 220,
                        backgroundColor: Colors.white),
              ),
              const SizedBox(height: 16),
              if (publicAddress.isNotEmpty) Text(SypcAddressValidator.inspect(publicAddress).label),
              Text(publicAddress.isEmpty ? 'Aun no hay direccion' :
                  !SypcWatchEntry.isPublicCandidate(publicAddress) ? 'Direccion guardada · requiere revision' :
                  publicAddress.length > _maxQrCharacters ? 'Direccion larga · copia el texto (sin QR)' : 'QR de direccion observada',
                  style: const TextStyle(color: _soft)),
              const SizedBox(height: 23),
              SelectableText(
                publicAddress.isEmpty
                    ? 'No hay direccion configurada'
                    : publicAddress,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.6),
              ),
              const SizedBox(height: 19),
              FilledButton.icon(
                onPressed: publicAddress.isEmpty ? onAddAddress : onCopy,
                icon: Icon(publicAddress.isEmpty ? Icons.settings : Icons.copy),
                label: Text(publicAddress.isEmpty
                    ? 'Configurar direccion'
                    : 'Copiar texto de direccion'),
              ),
            ]),
          ),
          const SizedBox(height: 17),
          const _WalletCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: _warning),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'QR funcional de una direccion IMPORTADA para observacion. Se comprueban red y checksum, pero NO propiedad ni fondos. El script P2S NO esta validado. Las entradas antiguas invalidas requieren revision y no generan QR. No envies fondos sin comprobarlo con la cartera original.',
                    style: TextStyle(color: _warning, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class SendPage extends StatelessWidget {
  const SendPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Enviar SYPC')),
        body: ListView(
          padding: const EdgeInsets.all(19),
          children: [
            const _PageHeading(
              title: 'Preparar envio',
              subtitle: 'Pantalla prevista · firma y envios desactivados',
            ),
            const SizedBox(height: 21),
            const _WalletCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Direccion del destinatario',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: 'Pendiente del validador nativo SYPC',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  SizedBox(height: 21),
                  Text('Cantidad SYPC',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  TextField(
                    enabled: false,
                    decoration: InputDecoration(hintText: '— SYPC'),
                  ),
                  SizedBox(height: 19),
                  Text('Comision de red: sin calcular',
                      style: TextStyle(color: _soft)),
                ],
              ),
            ),
            const SizedBox(height: 17),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Envios bloqueados en v0.6'),
            ),
            const SizedBox(height: 17),
            const _WalletCard(
                child: Text(
              'No hay semillas, claves, firmador, seleccion de UTXO ni broadcast. No se iniciara ninguna transferencia.',
              style: TextStyle(color: _warning, height: 1.5),
            )),
          ],
        ),
      );
}

class SecureTradePage extends StatefulWidget {
  const SecureTradePage({super.key});

  @override
  State<SecureTradePage> createState() => _SecureTradePageState();
}

class _SecureTradePageState extends State<SecureTradePage> {
  TradeSettlementMode _mode = TradeSettlementMode.atomicCrypto;

  @override
  Widget build(BuildContext context) {
    final isFiat = _mode == TradeSettlementMode.fiatMediated;
    return ListView(
      padding: const EdgeInsets.all(19),
      children: [
        const _PageHeading(
          title: 'SecureTrade',
          subtitle: 'Compraventa protegida por deposito en garantia',
        ),
        const SizedBox(height: 16),
        const _PrototypeBanner(),
        const SizedBox(height: 19),
        _WalletCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tipo de intercambio',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Wrap(spacing: 9, runSpacing: 9, children: [
                ChoiceChip(
                  label: const Text('Cripto / Cripto'),
                  selected: !isFiat,
                  onSelected: (_) => setState(
                      () => _mode = TradeSettlementMode.atomicCrypto),
                ),
                ChoiceChip(
                  label: const Text('SYPC / EUR'),
                  selected: isFiat,
                  onSelected: (_) => setState(
                      () => _mode = TradeSettlementMode.fiatMediated),
                ),
              ]),
              const SizedBox(height: 18),
              Text(
                isFiat
                    ? 'El contrato no puede comprobar por si solo un pago bancario. Se necesita mediacion/verificacion externa y un proceso de disputa.'
                    : 'Se estudiara un intercambio atomico con pruebas criptograficas compatibles. Todavia no existe un contrato desplegado.',
                style: const TextStyle(color: _soft, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 17),
        _WalletCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Como seria una operacion',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 17),
              const _TradeStep(
                number: '01',
                icon: Icons.people_outline,
                title: 'Acuerdo',
                description: 'Ambas partes aceptan importes y condiciones.',
              ),
              const _TradeStep(
                number: '02',
                icon: Icons.lock_outline,
                title: 'Deposito bloqueado',
                description: 'El contrato inmoviliza las monedas en cadena.',
              ),
              _TradeStep(
                number: '03',
                icon: isFiat
                    ? Icons.account_balance_outlined
                    : Icons.swap_horiz_rounded,
                title: isFiat ? 'Comprobacion del pago' : 'Prueba criptografica',
                description: isFiat
                    ? 'No basta con que el comprador pulse "pagado".'
                    : 'La condicion de intercambio debe verificarse en cadena.',
              ),
              const _TradeStep(
                number: '04',
                icon: Icons.gavel,
                title: 'Liquidacion o disputa',
                description:
                    'Liberacion, reembolso o resolucion segun reglas auditadas.',
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.shield_outlined),
          label: const Text('Crear operacion · no disponible'),
        ),
        const SizedBox(height: 18),
        const _WalletCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: _warning),
            SizedBox(width: 11),
            Expanded(
                child: Text(
              'Este es solo el flujo de diseno. No hay escrow desplegado, fondos retenidos, pagos verificados ni arbitraje operativo.',
              style: TextStyle(color: _warning, height: 1.5),
            )),
          ]),
        ),
      ],
    );
  }
}

class _PrototypeBanner extends StatelessWidget {
  const _PrototypeBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.09),
          border: Border.all(color: _gold.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          Icon(Icons.construction_outlined, color: _gold, size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text('SOLO DISENO · NO OPERA CON DINERO REAL',
                style: TextStyle(
                    color: _gold, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ]),
      );
}

class _TradeStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final bool isLast;

  const _TradeStep({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: _panelRaised,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: _purple, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$number · $title',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(color: _soft, height: 1.35)),
              ]),
            ),
          ],
        ),
      );
}

class ActivityPage extends StatelessWidget {
  final String address;
  final String apiOrigin;
  final SypcAddressReport? report;
  final bool reading;
  final String message;
  final VoidCallback onRefresh;

  const ActivityPage({super.key, required this.address, required this.apiOrigin,
    required this.report, required this.reading, required this.message,
    required this.onRefresh});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(19),
    children: [
      const _PageHeading(title: 'Actividad',
        subtitle: 'Consulta HTTPS de una direccion observada'),
      const SizedBox(height: 14),
      const Text('DATOS DECLARADOS POR UN SERVIDOR · NO VERIFICADOS EN CADENA',
        style: TextStyle(color: _warning, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      _WalletCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(address.isEmpty ? 'No hay direccion seleccionada' :
            'Direccion: ${address.substring(0, address.length > 14 ? 14 : address.length)}...',
            style: const TextStyle(color: _soft)),
          const SizedBox(height: 9),
          Text(apiOrigin.isEmpty ? 'No hay servidor HTTPS configurado' :
            'Servidor: $apiOrigin', style: const TextStyle(color: _soft)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: reading || !SypcWatchEntry.isPublicCandidate(address) || apiOrigin.isEmpty
              ? null : onRefresh,
            icon: const Icon(Icons.sync),
            label: const Text('Consultar saldos e historial'),
          ),
          if (reading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: _warning)),
        ])),
      const SizedBox(height: 18),
      if (report == null) const _WalletCard(child: Column(children: [
        Icon(Icons.receipt_long_outlined, color: _soft, size: 54),
        SizedBox(height: 12),
        Text('Sin historial remoto aceptado'),
        SizedBox(height: 7),
        Text('No se muestran movimientos ni cantidades ficticias. '
          'Configura una pasarela SYPC compatible para consultar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _soft)),
      ])) else ...[
        _WalletCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CANTIDADES REMOTAS · UNIDADES BASE',
              style: TextStyle(color: _warning, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Confirmado declarado: ${report!.confirmedBaseUnits}'),
            Text('Pendiente declarado: ${report!.pendingBaseUnits}'),
            Text('Inmaduro declarado: ${report!.immatureBaseUnits}'),
            const SizedBox(height: 10),
            Text('Altura declarada: ${report!.atHeight}',
              style: const TextStyle(color: _soft)),
            Text('Fecha UTC: ${report!.observedAtUtc.toIso8601String()}',
              style: const TextStyle(color: _soft)),
            const SizedBox(height: 9),
            const Text('Estas cifras NO se consideran saldo gastable ni '
              'recompensas confirmadas. 1 SYPC = 1.000.000.000 unidades base. '
              'El limite monetario no demuestra que los fondos existan.',
              style: TextStyle(color: _warning)),
          ])),
        const SizedBox(height: 16),
        Text('Movimientos declarados (${report!.transactions.length})',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (report!.transactions.isEmpty)
          const Text('El servidor no declara movimientos.',
            style: TextStyle(color: _soft)),
        for (final tx in report!.transactions) _WalletCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TX: ${tx.id.substring(0, 18)}...',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text('Sentido declarado: ${tx.direction}'),
            Text('Cantidad declarada: ${tx.amountBaseUnits} unidades base'),
            Text(tx.inclusionHeight == null ? 'Sin inclusion declarada' :
              'Bloque declarado: ${tx.inclusionHeight}'),
            Text(tx.inclusionHeight == null ? '0 confirmaciones declaradas' :
              '${report!.atHeight - tx.inclusionHeight! + 1} confirmaciones calculadas sobre el informe',
              style: const TextStyle(color: _warning)),
          ])),
      ],
    ],
  );
}

class SettingsPage extends StatefulWidget {
  final String publicAddress;
  final ValueChanged<String> onSaveAddress;
  final VoidCallback onManageWatch;
  final VoidCallback onExportBook;
  final VoidCallback onImportBook;
  final int watchCount;
  final String apiOrigin;
  final String connectionMessage;
  final SypcReadOnlyTip? reportedTip;
  final bool checking;
  final ValueChanged<String> onSaveApiOrigin;
  final VoidCallback onCheckApi;
  const SettingsPage({
    super.key,
    required this.publicAddress,
    required this.onSaveAddress,
    required this.onManageWatch,
    required this.onExportBook,
    required this.onImportBook,
    required this.watchCount,
    required this.apiOrigin,
    required this.connectionMessage,
    required this.reportedTip,
    required this.checking,
    required this.onSaveApiOrigin,
    required this.onCheckApi,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _address;
  late final TextEditingController _endpoint;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.publicAddress);
    _endpoint = TextEditingController(text: widget.apiOrigin);
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.publicAddress != widget.publicAddress &&
        _address.text.trim() != widget.publicAddress) {
      _address.text = widget.publicAddress;
    }
    if (oldWidget.apiOrigin != widget.apiOrigin &&
        _endpoint.text.trim() != widget.apiOrigin) {
      _endpoint.text = widget.apiOrigin;
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(19),
        children: [
          const _PageHeading(
              title: 'Ajustes', subtitle: 'Seguridad y configuracion de testnet'),
          const SizedBox(height: 21),
          _WalletCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Anadir direccion publica · solo lectura',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _address,
                    minLines: 2,
                    maxLines: 3,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                        hintText: 'Pega solo una direccion publica'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'NUNCA introduzcas frases de recuperacion, semillas, contrasenas ni claves privadas.',
                    style: TextStyle(color: _warning, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => widget.onSaveAddress(_address.text),
                    child: const Text('Guardar direccion en el movil'),
                  ),
                  const SizedBox(height: 12),
                  Text('Direcciones guardadas: ${widget.watchCount}',
                    style: const TextStyle(color: _soft)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: widget.onManageWatch,
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('Administrar direcciones'),
                  ),
                  const SizedBox(height: 10),
                  const Text('Copia de la libreta PUBLICA (no contiene claves)',
                    style: TextStyle(color: _soft)),
                  const SizedBox(height: 9),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(onPressed: widget.onExportBook,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Copiar respaldo')),
                    OutlinedButton.icon(onPressed: widget.onImportBook,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Restaurar respaldo')),
                  ]),
                ]),
          ),
          const SizedBox(height: 17),
          _WalletCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Servidor HTTPS · solo lectura',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Configura un dominio publico HTTPS que ofrezca GET /v1/status. '
                'La API SYPC todavia no esta desplegada.',
                style: TextStyle(color: _soft, height: 1.4)),
              const SizedBox(height: 12),
              TextField(
                controller: _endpoint,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  hintText: 'https://api.ejemplo.org',
                  labelText: 'Origen HTTPS (sin ruta ni tokens)',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 9, runSpacing: 8, children: [
                OutlinedButton(
                  onPressed: () => widget.onSaveApiOrigin(_endpoint.text),
                  child: const Text('Guardar servidor'),
                ),
                FilledButton.icon(
                  onPressed: widget.checking || widget.apiOrigin.isEmpty
                      ? null : widget.onCheckApi,
                  icon: const Icon(Icons.public),
                  label: const Text('Consultar HTTPS'),
                ),
              ]),
              if (widget.checking) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 13),
              Text(widget.connectionMessage,
                style: const TextStyle(color: _warning)),
              if (widget.reportedTip != null) ...[
                const SizedBox(height: 8),
                Text('Altura declarada: ${widget.reportedTip!.fullHeight}',
                  style: const TextStyle(color: _soft)),
              ],
              const SizedBox(height: 9),
              const Text('Sin contrasenas, semillas ni tokens. La respuesta no '
                'demuestra por si sola el consenso ni acredita saldos.',
                style: TextStyle(color: _soft, fontSize: 12)),
            ],
          )),
          const SizedBox(height: 17),
          const _WalletCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estado de seguridad',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  SizedBox(height: 13),
                  _SecurityLine(label: 'Custodia de claves', status: 'No implementada'),
                  Divider(height: 20),
                  _SecurityLine(label: 'API de lectura', status: 'Sin verificar'),
                  Divider(height: 20),
                  _SecurityLine(label: 'Firma y envios', status: 'Bloqueados'),
                  Divider(height: 20),
                  _SecurityLine(label: 'SecureTrade', status: 'Solo diseno'),
                ]),
          ),
          const SizedBox(height: 17),
          const _WalletCard(
              child: Text(
            'Los nodos privados no deben exponerse a Internet. La cartera personal futura sera independiente de las carteras Minera, Solidaridad y Desarrollo.',
            style: TextStyle(color: _soft, height: 1.5),
          )),
          const SizedBox(height: 18),
          const Center(
            child: Text('SYPC Wallet 0.6.1 · WATCH-ONLY EXPERIMENTAL',
                style: TextStyle(color: _soft, fontSize: 12)),
          ),
        ],
      );
}

class _SecurityLine extends StatelessWidget {
  final String label;
  final String status;
  const _SecurityLine({required this.label, required this.status});

  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.lock_outline, size: 18, color: _warning),
        const SizedBox(width: 9),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Flexible(
            child: Text(status,
                textAlign: TextAlign.end,
                style: const TextStyle(color: _warning, fontSize: 12))),
      ]);
}
