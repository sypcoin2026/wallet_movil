import 'dart:convert';

import 'sypc_watch_only_guard.dart';
import 'sypc_address_validator.dart';

/// Local watch-only address catalogue. It NEVER creates/owns signing keys.
/// New entries require valid SYPC encoding. Legacy entries remain available
/// for review; no address inspection establishes ownership, UTXOs or consensus.
class SypcWatchEntry {
  final String label;
  final String address;
  const SypcWatchEntry({required this.label, required this.address});

  static final RegExp _base58 = RegExp(r'^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]+$');
  static final RegExp _controls = RegExp(r'[\x00-\x1f\x7f]');

  SypcAddressInspection get validation => SypcAddressValidator.inspect(address);
  bool get needsReview => !validation.encodingValid;

  /// Compatibility name; now enforces SYPC network, checksum and structure.
  static bool isPublicCandidate(String input) =>
      SypcAddressValidator.inspect(input).encodingValid;

  /// v0.6 backups admitted these strings. Preserve them with an explicit
  /// review status, but never allow this migration rule in add() or queries.
  static bool _isLegacyCandidate(String value) =>
      value.length >= 30 && value.length <= 110 && _base58.hasMatch(value);

  static String safeLabel(String input) {
    final value = input.trim();
    if (value.isEmpty || value.length > 48 || _controls.hasMatch(value)) {
      throw const FormatException('Etiqueta invalida (1-48 caracteres).');
    }
    return value;
  }

  Map<String, String> toJson() => {'label': label, 'address': address};

  factory SypcWatchEntry.fromJson(Object? value) {
    if (value is! Map || value['label'] is! String ||
        value['address'] is! String) {
      throw const FormatException('Registro watch-only invalido.');
    }
    final label = safeLabel(value['label'] as String);
    final address = (value['address'] as String).trim();
    if (!isPublicCandidate(address) && !_isLegacyCandidate(address)) {
      throw const FormatException('Direccion publica invalida.');
    }
    return SypcWatchEntry(label: label, address: address);
  }
}

class SypcWatchBook {
  final List<SypcWatchEntry> entries;
  final String selectedAddress;
  final String apiOrigin;

  static const int maxEntries = 20;
  // Fits 20 long P2S envelopes plus escaped labels and existing metadata.
  static const int maxBackupLength = 131072;
  const SypcWatchBook({this.entries = const [], this.selectedAddress = '', this.apiOrigin = ''});

  String get activeAddress => selectedAddress;

  SypcWatchBook add({required String address, required String label}) {
    final clean = address.trim();
    if (!SypcWatchEntry.isPublicCandidate(clean)) {
      throw const FormatException('Direccion SYPC invalida: revisa red, checksum y estructura. No pegues semillas.');
    }
    final cleanLabel = SypcWatchEntry.safeLabel(label);
    if (entries.length >= maxEntries) {
      throw const FormatException('Limite de 20 direcciones observadas.');
    }
    if (entries.any((e) => e.address == clean)) {
      throw const FormatException('Esta direccion ya esta guardada.');
    }
    return SypcWatchBook(
      entries: [...entries, SypcWatchEntry(label: cleanLabel, address: clean)],
      selectedAddress: clean,
      apiOrigin: apiOrigin,
    );
  }

  SypcWatchBook select(String address) {
    if (!entries.any((e) => e.address == address)) {
      throw const FormatException('Direccion no registrada.');
    }
    return SypcWatchBook(entries: entries, selectedAddress: address, apiOrigin: apiOrigin);
  }

  SypcWatchBook remove(String address) {
    if (!entries.any((e) => e.address == address)) {
      throw const FormatException('Direccion no registrada.');
    }
    final remaining = entries.where((e) => e.address != address).toList();
    final newSelected = selectedAddress == address
        ? (remaining.isEmpty ? '' : remaining.first.address)
        : selectedAddress;
    return SypcWatchBook(entries: remaining, selectedAddress: newSelected, apiOrigin: apiOrigin);
  }

  SypcWatchBook rename(String address, String label) {
    if (!entries.any((e) => e.address == address)) {
      throw const FormatException('Direccion no registrada.');
    }
    final clean = SypcWatchEntry.safeLabel(label);
    return SypcWatchBook(
      entries: [for (final e in entries)
        e.address == address ? SypcWatchEntry(label: clean, address: address) : e],
      selectedAddress: selectedAddress,
      apiOrigin: apiOrigin,
    );
  }

  SypcWatchBook withOrigin(String origin) => SypcWatchBook(
    entries: entries, selectedAddress: selectedAddress, apiOrigin: origin.trim());

  String encode() => jsonEncode({
    'schemaVersion': 1,
    'networkId': SypcReadOnlyPolicy.networkId,
    'genesisId': SypcReadOnlyPolicy.genesisId,
    'selectedAddress': selectedAddress,
    'apiOrigin': apiOrigin,
    'entries': entries.map((e) => e.toJson()).toList(),
  });

  factory SypcWatchBook.decode(String raw) {
    if (raw.length > maxBackupLength) {
      throw const FormatException('Datos locales demasiado grandes.');
    }
    final value = jsonDecode(raw);
    if (value is! Map || value['schemaVersion'] != 1 ||
        value['networkId'] != SypcReadOnlyPolicy.networkId ||
        value['genesisId'] != SypcReadOnlyPolicy.genesisId ||
        value['entries'] is! List ||
        value['selectedAddress'] is! String ||
        value['apiOrigin'] is! String) {
      throw const FormatException('Datos locales de otra red o version.');
    }
    final rawEntries = value['entries'] as List;
    if (rawEntries.length > maxEntries) {
      throw const FormatException('Exceso de direcciones guardadas.');
    }
    final entries = rawEntries.map((e) => SypcWatchEntry.fromJson(e)).toList();
    if (entries.map((e) => e.address).toSet().length != entries.length) {
      throw const FormatException('Direcciones duplicadas.');
    }
    final selected = value['selectedAddress'] as String;
    if (selected.isNotEmpty && !entries.any((e) => e.address == selected)) {
      throw const FormatException('Seleccion local incoherente.');
    }
    final origin = value['apiOrigin'] as String;
    if (origin.length > 220 || (origin.isNotEmpty && !origin.startsWith('https://'))) {
      throw const FormatException('Origen de API local invalido.');
    }
    return SypcWatchBook(entries: entries, selectedAddress: selected, apiOrigin: origin);
  }
}
