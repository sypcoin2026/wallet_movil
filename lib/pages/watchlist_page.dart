import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/sypc_watch_book.dart';

/// Manages public metadata and displays local encoding/review status.
class SypcWatchlistPage extends StatelessWidget {
  final SypcWatchBook book;
  final Future<bool> Function(String address) onSelect;
  final Future<bool> Function(String address) onDelete;
  final Future<bool> Function(String address, String label) onRename;

  const SypcWatchlistPage({super.key, required this.book,
    required this.onSelect, required this.onDelete, required this.onRename});

  Future<void> _rename(BuildContext context, SypcWatchEntry entry) async {
    final controller = TextEditingController(text: entry.label);
    final updated = await showDialog<String>(context: context, builder: (dialogContext) =>
      AlertDialog(title: const Text('Cambiar etiqueta'), content: TextField(
        controller: controller, maxLength: 48, decoration: const InputDecoration(labelText: 'Nombre'),
      ), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Guardar'))]));
    controller.dispose();
    if (updated != null) await onRename(entry.address, updated);
  }

  Future<void> _delete(BuildContext context, SypcWatchEntry entry) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Quitar de observacion'),
      content: Text('Eliminar ${entry.label} de la lista LOCAL? No afecta a la blockchain.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar'))]));
    if (confirmed == true) await onDelete(entry.address);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Direcciones observadas')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('PUBLICAS · SOLO LECTURA', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('No son carteras creadas por esta app. No guardamos claves privadas. '
        'Se comprueban red y checksum. Los scripts P2S no se validan. Ninguna direccion demuestra fondos ni propiedad.'),
      const SizedBox(height: 20),
      if (book.entries.isEmpty) const Text('No hay direcciones guardadas.'),
      for (final entry in book.entries) Card(
        child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(entry.label,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              if (book.selectedAddress == entry.address)
                const Icon(Icons.check_circle, color: Color(0xFF41DBB1)),
            ]),
            const SizedBox(height: 8),
            Text(entry.validation.label),
            const SizedBox(height: 8),
            SelectableText(entry.address, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(spacing: 5, runSpacing: 5, children: [
              TextButton.icon(onPressed: book.selectedAddress == entry.address ? null :
                () => onSelect(entry.address), icon: const Icon(Icons.check),
                label: const Text('Seleccionar')),
              IconButton(tooltip: 'Copiar direccion publica', icon: const Icon(Icons.copy),
                onPressed: () => Clipboard.setData(ClipboardData(text: entry.address))),
              IconButton(tooltip: 'Cambiar etiqueta', icon: const Icon(Icons.edit_outlined),
                onPressed: () => _rename(context, entry)),
              IconButton(tooltip: 'Eliminar de observacion', icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, entry)),
            ]),
          ]))),
    ]),
  );
}
