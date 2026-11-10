import 'package:flutter_test/flutter_test.dart';
import 'package:sypc_wallet/domain/sypc_models.dart';

void main() {
  test('SYPC amounts preserve exact base-unit arithmetic', () {
    final a = SypcAmount(BigInt.parse('100000000000000000001'));
    final b = SypcAmount(BigInt.from(9));
    expect((a + b).baseUnits.toString(), '100000000000000000010');
  });

  test('Chain identity requires network and genesis agreement', () {
    const identity = ChainIdentity(
      networkId: 'private-testnet',
      genesisId: 'expected-genesis',
      bestBlockId: 'block',
      height: 300,
    );
    expect(identity.matches(expectedNetwork: 'private-testnet',
      expectedGenesis: 'expected-genesis'), isTrue);
    expect(identity.matches(expectedNetwork: 'other',
      expectedGenesis: 'expected-genesis'), isFalse);
    expect(identity.matches(expectedNetwork: 'private-testnet',
      expectedGenesis: 'wrong-genesis'), isFalse);
  });

  test('The address draft rejects recovery phrases and URI payloads', () {
    expect(PublicAddressDraftGuard.isCandidate('A3examplePublicAddress9'), isTrue);
    expect(PublicAddressDraftGuard.isCandidate('one two three four'), isFalse);
    expect(PublicAddressDraftGuard.isCandidate('sypc:address'), isFalse);
    expect(PublicAddressDraftGuard.isCandidate('  '), isFalse);
  });

  test('Prototype capabilities fail closed', () {
    expect(WalletCapabilities.hasVerifiedReadApi, isFalse);
    expect(WalletCapabilities.canGenerateKeys, isFalse);
    expect(WalletCapabilities.canSignTransfers, isFalse);
    expect(WalletCapabilities.canBroadcast, isFalse);
    expect(WalletCapabilities.canLockEscrow, isFalse);
    expect(WalletCapabilities.canReleaseEscrow, isFalse);
  });

  test('Fiat claims never trigger automatic release', () {
    expect(EscrowDraftPolicy.mayAutoRelease(
      mode: TradeSettlementMode.fiatMediated,
      cryptographicSettlementProof: true), isFalse);
    expect(EscrowDraftPolicy.mayAutoRelease(
      mode: TradeSettlementMode.atomicCrypto,
      cryptographicSettlementProof: false), isFalse);
    expect(EscrowDraftPolicy.mayAutoRelease(
      mode: TradeSettlementMode.atomicCrypto,
      cryptographicSettlementProof: true), isFalse);
  });
}
