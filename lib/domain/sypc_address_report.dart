import 'sypc_watch_book.dart';
import 'sypc_watch_only_guard.dart';
import '../services/sypc_status_client.dart';

/// A remote server's untrusted claim. NOT a verified UTXO state or spendable
/// wallet balance. Amounts stay in exact integer base units (10^-9 SYPC);
/// the scale and semantic cap do not validate the server's claims.
class SypcReportedTransaction {
  final String id;
  final String direction;
  final int? inclusionHeight;
  final BigInt amountBaseUnits;

  const SypcReportedTransaction({required this.id, required this.direction,
    required this.inclusionHeight, required this.amountBaseUnits});
}

class SypcAddressReport {
  final String address;
  final int atHeight;
  final String bestFullBlockId;
  final DateTime observedAtUtc;
  final BigInt confirmedBaseUnits;
  final BigInt pendingBaseUnits;
  final BigInt immatureBaseUnits;
  final List<SypcReportedTransaction> transactions;

  const SypcAddressReport({required this.address, required this.atHeight,
    required this.bestFullBlockId, required this.observedAtUtc,
    required this.confirmedBaseUnits, required this.pendingBaseUnits,
    required this.immatureBaseUnits, required this.transactions});

  /// Exact raw representation; never rounded through floating point.
  String get confirmedRaw => confirmedBaseUnits.toString();
}

class SypcAddressReportGuard {
  const SypcAddressReportGuard._();
  static final RegExp _hex = RegExp(r'^[0-9a-f]{64}$');
  static const int maxTransactions = 30;

  static SypcAddressReport inspect(Map<String, dynamic> payload,
      {required String requestedAddress, required SypcReadOnlyTip tip,
      required DateTime nowUtc}) {
    // Check network identity and exact block tip, not merely a reported height.
    if (payload['schemaVersion'] != SypcReadOnlyPolicy.schemaVersion ||
        payload['networkId'] != SypcReadOnlyPolicy.networkId ||
        payload['genesisId'] != SypcReadOnlyPolicy.genesisId) {
      throw const SypcReadException('ADDRESS_NETWORK_MISMATCH');
    }
    if (!SypcWatchEntry.isPublicCandidate(requestedAddress) ||
        payload['address'] != requestedAddress) {
      throw const SypcReadException('ADDRESS_MISMATCH');
    }
    if (payload['atHeight'] != tip.fullHeight ||
        payload['bestFullBlockId'] != tip.bestFullBlockId ||
        payload['bestFullBlockId'] is! String ||
        !_hex.hasMatch(payload['bestFullBlockId'] as String)) {
      throw const SypcReadException('ADDRESS_TIP_MISMATCH');
    }
    final rawTime = payload['observedAtUnixMs'];
    if (rawTime is! int || rawTime <= 0 || rawTime > 8640000000000000) {
      throw const SypcReadException('ADDRESS_TIME_INVALID');
    }
    final observed = DateTime.fromMillisecondsSinceEpoch(rawTime, isUtc: true);
    final now = nowUtc.toUtc();
    if (observed.isBefore(now.subtract(SypcReadOnlyPolicy.maxSnapshotAge)) ||
        observed.isAfter(now.add(SypcReadOnlyPolicy.maxFutureClockSkew)) ||
        observed.difference(tip.observedAtUtc).abs() > const Duration(minutes: 2)) {
      throw const SypcReadException('ADDRESS_STALE');
    }
    BigInt parseAmount(Object? value) {
      final n = SypcReadOnlyGuard.parseUnsignedBaseUnits(value);
      if (n == null) throw const SypcReadException('ADDRESS_AMOUNT_INVALID');
      return n;
    }
    // Bound each claim independently. These categories can overlap; neither
    // their sum nor the sum of historical movements is a supply invariant.
    final confirmed = parseAmount(payload['confirmedBaseUnits']);
    final pending = parseAmount(payload['pendingBaseUnits']);
    final immature = parseAmount(payload['immatureBaseUnits']);
    final rawTxs = payload['transactions'];
    if (rawTxs is! List || rawTxs.length > maxTransactions) {
      throw const SypcReadException('ADDRESS_HISTORY_INVALID');
    }
    final seen = <String>{};
    final txs = <SypcReportedTransaction>[];
    int? previousIncludedHeight;
    for (final raw in rawTxs) {
      if (raw is! Map) throw const SypcReadException('ADDRESS_HISTORY_INVALID');
      final id = raw['id'];
      final direction = raw['direction'];
      final height = raw['inclusionHeight'];
      if (id is! String || !_hex.hasMatch(id) || !seen.add(id) ||
          direction is! String ||
          !const ['incoming', 'outgoing', 'unknown'].contains(direction) ||
          (height != null && (height is! int || height < 1 || height > tip.fullHeight))) {
        throw const SypcReadException('ADDRESS_HISTORY_INVALID');
      }
      // Require descending order among confirmed transactions, but allow
      // unconfirmed entries (null inclusion height) without implying finality.
      if (height is int) {
        if (previousIncludedHeight != null && height > previousIncludedHeight) {
          throw const SypcReadException('ADDRESS_HISTORY_ORDER_INVALID');
        }
        previousIncludedHeight = height;
      }
      txs.add(SypcReportedTransaction(id: id, direction: direction,
        inclusionHeight: height, amountBaseUnits: parseAmount(raw['amountBaseUnits'])));
    }
    return SypcAddressReport(address: requestedAddress, atHeight: tip.fullHeight,
      bestFullBlockId: tip.bestFullBlockId, observedAtUtc: observed,
      confirmedBaseUnits: confirmed, pendingBaseUnits: pending,
      immatureBaseUnits: immature, transactions: List.unmodifiable(txs));
  }
}
