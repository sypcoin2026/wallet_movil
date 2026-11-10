// Domain placeholders for the SYPC mobile client.
// These are pure data contracts, NOT implementations of the blockchain.
// In particular, they cannot infer spendable balance or verify signatures.

// Exact amounts use integer base units. The SYPC decimal scale is NOT fixed
// here because it must be read from the approved consensus specification.
class SypcAmount {
  final BigInt baseUnits;
  const SypcAmount(this.baseUnits);

  SypcAmount operator +(SypcAmount other) =>
      SypcAmount(baseUnits + other.baseUnits);

  @override
  bool operator ==(Object other) =>
      other is SypcAmount && other.baseUnits == baseUnits;

  @override
  int get hashCode => baseUnits.hashCode;
}

class ChainIdentity {
  final String networkId;
  final String genesisId;
  final String bestBlockId;
  final int height;

  const ChainIdentity({
    required this.networkId,
    required this.genesisId,
    required this.bestBlockId,
    required this.height,
  });

  /// The caller supplies protocol constants from independently approved tests.
  /// A matching identity is necessary but NOT sufficient to trust a node.
  bool matches({required String expectedNetwork, required String expectedGenesis}) =>
      networkId == expectedNetwork &&
      genesisId == expectedGenesis &&
      height >= 0;
}

class AddressSnapshot {
  final String publicAddress;
  final int atHeight;
  final SypcAmount? spendable;
  final SypcAmount? pending;
  final SypcAmount? immature;

  const AddressSnapshot({
    required this.publicAddress,
    required this.atHeight,
    this.spendable,
    this.pending,
    this.immature,
  });
}

/// This is a defensive INPUT guard only. It does not validate SYPcoin Base58,
/// network prefix, checksum, script or destination ownership.
class PublicAddressDraftGuard {
  static bool isCandidate(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.length > 1024) return false;
    // Prevent accidental saving of recovery phrases, secrets with whitespace,
    // URI payloads and multiline data as a public address.
    return RegExp(r'^[A-Za-z0-9]+$').hasMatch(text);
  }
}

/// Escrow is architecture only. No script, lock, verifier or dispute service
/// has been built. These gates deliberately fail closed for testnet v0.2.
enum TradeSettlementMode { atomicCrypto, fiatMediated }

enum TradeStage {
  proposal,
  depositAwaited,
  deposited,
  externalPaymentClaimed,
  settlementReview,
  disputed,
  completed,
  refunded,
}

class WalletCapabilities {
  const WalletCapabilities._();

  static const bool hasVerifiedReadApi = false;
  static const bool canGenerateKeys = false;
  static const bool canSignTransfers = false;
  static const bool canBroadcast = false;
  static const bool canLockEscrow = false;
  static const bool canReleaseEscrow = false;
}

class EscrowDraftPolicy {
  const EscrowDraftPolicy._();

  /// A user saying "I paid" is NOT verified settlement. Fiat payment is
  /// external, reversible in some circumstances, and needs an approved
  /// mediation/attestation process before funds could ever be released.
  static bool mayAutoRelease({
    required TradeSettlementMode mode,
    required bool cryptographicSettlementProof,
  }) => mode == TradeSettlementMode.atomicCrypto &&
      cryptographicSettlementProof &&
      WalletCapabilities.canReleaseEscrow;
}
