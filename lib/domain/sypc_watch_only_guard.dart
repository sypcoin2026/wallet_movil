/// SYPC Wallet v0.4: strict parsing of a FUTURE read-only bridge payload.
///
/// This module has no secrets or signing. HTTPS is implemented separately.
/// A valid payload is only structurally plausible: it is NOT proof that a
/// remote server has honestly validated blocks or holds the canonical chain.
class SypcReadOnlyPolicy {
  const SypcReadOnlyPolicy._();

  static const int schemaVersion = 1;
  static const String networkId = 'SypPrivateV30';
  static const String genesisId =
      '8b404d4c2f9c394e36faf7992c92bb670b3bf7d4e14c8e83f9acb323d67d030d';
  // Private profile: SypV30NativeProfile -> SypV29PrivateGenesisCandidate
  // -> SypV20GenesisInventory (28M), and SypCurrencyDisplay (9 decimals).
  // Semantic bound on each server claim, NOT verification of consensus.
  static const int decimals = 9;
  static final BigInt baseUnitsPerSypc = BigInt.from(1000000000);
  static final BigInt maximumSupplySypc = BigInt.from(28000000);
  static final BigInt maximumBaseUnits = maximumSupplySypc * baseUnitsPerSypc;

  static const Duration maxSnapshotAge = Duration(minutes: 10);
  static const Duration maxFutureClockSkew = Duration(seconds: 30);

  /// Never infer live read access from successful JSON validation.
  static const bool liveApiEnabled = false;
  static const bool sendingEnabled = false;
  static const bool keysEnabled = false;
}

class SypcReadOnlyTip {
  final String networkId;
  final String genesisId;
  final int fullHeight;
  final int headersHeight;
  final String bestFullBlockId;
  final String stateRoot;
  final DateTime observedAtUtc;

  const SypcReadOnlyTip({
    required this.networkId,
    required this.genesisId,
    required this.fullHeight,
    required this.headersHeight,
    required this.bestFullBlockId,
    required this.stateRoot,
    required this.observedAtUtc,
  });
}

class SypcTipInspection {
  final SypcReadOnlyTip? tip;
  final String? rejectionCode;

  const SypcTipInspection._(this.tip, this.rejectionCode);
  bool get accepted => tip != null && rejectionCode == null;

  static SypcTipInspection reject(String code) =>
      SypcTipInspection._(null, code);
  static SypcTipInspection accept(SypcReadOnlyTip tip) =>
      SypcTipInspection._(tip, null);
}

class SypcReadOnlyGuard {
  const SypcReadOnlyGuard._();

  static final RegExp _hex32 = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp _unsignedDecimal = RegExp(r'^(0|[1-9][0-9]*)$');

  /// Validates an app-defined read-only bridge format, not the raw Ergo API.
  /// A caller must separately enforce authenticated transport, TLS where
  /// needed, response-size limits, and consensus/checkpoint verification.
  ///
  /// Expected fields:
  /// schemaVersion, networkId, genesisId, fullHeight, headersHeight,
  /// bestFullBlockId, stateRoot, observedAtUnixMs, isSynced, isMining.
  static SypcTipInspection inspect(
    Map<String, dynamic> payload, {
    required DateTime nowUtc,
  }) {
    if (payload['schemaVersion'] is! int ||
        payload['schemaVersion'] != SypcReadOnlyPolicy.schemaVersion) {
      return SypcTipInspection.reject('SCHEMA_UNSUPPORTED');
    }
    if (payload['networkId'] != SypcReadOnlyPolicy.networkId) {
      return SypcTipInspection.reject('NETWORK_MISMATCH');
    }
    if (payload['genesisId'] != SypcReadOnlyPolicy.genesisId) {
      return SypcTipInspection.reject('GENESIS_MISMATCH');
    }

    final fullHeight = payload['fullHeight'];
    final headersHeight = payload['headersHeight'];
    if (fullHeight is! int || headersHeight is! int ||
        fullHeight < 1 || headersHeight != fullHeight ||
        headersHeight > 1000000000) {
      return SypcTipInspection.reject('HEIGHT_INVALID');
    }

    final blockId = payload['bestFullBlockId'];
    final root = payload['stateRoot'];
    if (blockId is! String || !_hex32.hasMatch(blockId) ||
        root is! String || !_hex32.hasMatch(root)) {
      return SypcTipInspection.reject('CHAIN_HASH_INVALID');
    }
    if (payload['isMining'] != false) {
      return SypcTipInspection.reject('RECEIVER_MUST_NOT_MINE');
    }
    if (payload['isSynced'] != true) {
      return SypcTipInspection.reject('NOT_SYNCHRONIZED');
    }
    final stamp = payload['observedAtUnixMs'];
    if (stamp is! int || stamp <= 0) {
      return SypcTipInspection.reject('TIME_INVALID');
    }
    if (stamp > 8640000000000000) {
      return SypcTipInspection.reject('TIME_INVALID');
    }
    final observed = DateTime.fromMillisecondsSinceEpoch(stamp, isUtc: true);
    final now = nowUtc.toUtc();
    if (observed.isAfter(now.add(SypcReadOnlyPolicy.maxFutureClockSkew)) ||
        observed.isBefore(now.subtract(SypcReadOnlyPolicy.maxSnapshotAge))) {
      return SypcTipInspection.reject('STALE_OR_FUTURE_SNAPSHOT');
    }

    return SypcTipInspection.accept(SypcReadOnlyTip(
      networkId: SypcReadOnlyPolicy.networkId,
      genesisId: SypcReadOnlyPolicy.genesisId,
      fullHeight: fullHeight,
      headersHeight: headersHeight,
      bestFullBlockId: blockId,
      stateRoot: root,
      observedAtUtc: observed,
    ));
  }

  /// Decimal integer string only. No floats, exponent notation or negatives.
  /// This does not determine whether the claimed amount actually exists.
  static BigInt? parseUnsignedBaseUnits(Object? raw) {
    if (raw is! String || raw.length > 17 ||
        !_unsignedDecimal.hasMatch(raw)) {
      return null;
    }
    final value = BigInt.tryParse(raw);
    return value != null && value <= SypcReadOnlyPolicy.maximumBaseUnits
        ? value : null;
  }
}
