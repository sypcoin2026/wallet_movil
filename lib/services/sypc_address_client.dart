import '../domain/sypc_address_report.dart';
import '../domain/sypc_watch_book.dart';
import 'sypc_status_client.dart';

/// Two explicit, manual GETs. We first validate the reported chain tip, then
/// require the address report to refer to that *same* tip. Still NOT proof of
/// consensus, UTXO ownership, finality or canonicality.
class SypcAddressClient {
  final SypcJsonFetcher fetcher;
  SypcAddressClient({SypcJsonFetcher? fetcher})
      : fetcher = fetcher ?? HttpSypcJsonFetcher();

  Future<SypcAddressReport> check(String origin, String address,
      {DateTime? nowUtc}) async {
    if (!SypcWatchEntry.isPublicCandidate(address) || address != address.trim()) {
      throw const SypcReadException('ADDRESS_INVALID');
    }
    final statusUrl = SypcEndpointPolicy.statusUri(origin);
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final inspected = await SypcStatusClient(fetcher: fetcher)
        .check(origin, nowUtc: now);
    if (!inspected.accepted || inspected.tip == null) {
      throw SypcReadException(inspected.rejectionCode ?? 'STATUS_INVALID');
    }
    final url = statusUrl.replace(pathSegments: [
      'v1', 'addresses', address, 'summary',
    ]);
    final payload = await fetcher.fetch(url);
    return SypcAddressReportGuard.inspect(payload,
      requestedAddress: address, tip: inspected.tip!, nowUtc: now);
  }
}
