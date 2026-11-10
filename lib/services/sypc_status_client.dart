import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/sypc_watch_only_guard.dart';

/// All exceptions expose stable codes, never the server URL or response body.
class SypcReadException implements Exception {
  final String code;
  const SypcReadException(this.code);

  @override
  String toString() => 'SypcReadException($code)';
}

/// The configured endpoint is a *public HTTPS origin*, never an Ergo REST URL.
class SypcEndpointPolicy {
  const SypcEndpointPolicy._();

  static Uri statusUri(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.length > 220) {
      throw const SypcReadException('ENDPOINT_INVALID');
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.port != 443) {
      throw const SypcReadException('HTTPS_ORIGIN_REQUIRED');
    }
    final host = uri.host.toLowerCase();
    if (host.length > 253 ||
        InternetAddress.tryParse(host) != null ||
        host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal') ||
        host.endsWith('.test')) {
      throw const SypcReadException('PUBLIC_HOST_REQUIRED');
    }
    final labels = host.split('.');
    final labelPattern = RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$');
    if (labels.length < 2 || labels.last.length < 2 ||
        labels.any((part) => part.length > 63 || !labelPattern.hasMatch(part))) {
      throw const SypcReadException('PUBLIC_HOST_REQUIRED');
    }
    return uri.replace(path: '/v1/status', query: null, fragment: null);
  }
}

/// Injection point for tests; production uses HttpSypcJsonFetcher only.
abstract class SypcJsonFetcher {
  Future<Map<String, dynamic>> fetch(Uri url);
}

class HttpSypcJsonFetcher implements SypcJsonFetcher {
  static const int maxBytes = 32768;
  static const Duration timeout = Duration(seconds: 8);

  @override
  Future<Map<String, dynamic>> fetch(Uri url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..autoUncompress = false;
    try {
      final request = await client.getUrl(url).timeout(timeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final response = await request.close().timeout(timeout);
      if (response.isRedirect) {
        throw const SypcReadException('REDIRECT_FORBIDDEN');
      }
      if (response.statusCode != HttpStatus.ok) {
        throw const SypcReadException('HTTP_NOT_OK');
      }
      if (response.headers.contentType?.mimeType != 'application/json') {
        throw const SypcReadException('JSON_CONTENT_TYPE_REQUIRED');
      }
      if (response.contentLength > maxBytes) {
        throw const SypcReadException('RESPONSE_TOO_LARGE');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(timeout)) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const SypcReadException('RESPONSE_TOO_LARGE');
        }
        bytes.add(chunk);
      }
      final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (decoded is! Map<String, dynamic>) {
        throw const SypcReadException('JSON_OBJECT_REQUIRED');
      }
      return decoded;
    } on SypcReadException {
      rethrow;
    } on TimeoutException {
      throw const SypcReadException('TIMEOUT');
    } on HandshakeException {
      throw const SypcReadException('TLS_ERROR');
    } on SocketException {
      throw const SypcReadException('NETWORK_UNREACHABLE');
    } on FormatException {
      throw const SypcReadException('JSON_INVALID');
    } on HttpException {
      throw const SypcReadException('HTTP_ERROR');
    } catch (_) {
      throw const SypcReadException('NETWORK_ERROR');
    } finally {
      client.close(force: true);
    }
  }
}

/// Performs a single manual, read-only request. An accepted *server report*
/// is NOT consensus verification, a trusted checkpoint, or a wallet balance.
class SypcStatusClient {
  final SypcJsonFetcher fetcher;
  SypcStatusClient({SypcJsonFetcher? fetcher})
      : fetcher = fetcher ?? HttpSypcJsonFetcher();

  Future<SypcTipInspection> check(String origin, {DateTime? nowUtc}) async {
    final url = SypcEndpointPolicy.statusUri(origin);
    final payload = await fetcher.fetch(url);
    return SypcReadOnlyGuard.inspect(
      payload, nowUtc: (nowUtc ?? DateTime.now().toUtc()),
    );
  }
}

String sypcReadErrorLabel(String code) {
  switch (code) {
    case 'ENDPOINT_INVALID':
    case 'HTTPS_ORIGIN_REQUIRED':
    case 'PUBLIC_HOST_REQUIRED':
      return 'Escribe un dominio publico HTTPS, sin ruta ni contrasenas.';
    case 'NETWORK_UNREACHABLE':
    case 'TIMEOUT':
      return 'No se ha podido contactar con el servicio HTTPS.';
    case 'TLS_ERROR':
      return 'Certificado TLS no valido. Conexion rechazada.';
    case 'NETWORK_MISMATCH':
    case 'GENESIS_MISMATCH':
      return 'El servidor no corresponde a nuestra testnet SYPC.';
    case 'NOT_SYNCHRONIZED':
    case 'HEIGHT_INVALID':
      return 'El servidor no informa de una cadena sincronizada.';
    case 'STALE_OR_FUTURE_SNAPSHOT':
    case 'ADDRESS_STALE':
    case 'ADDRESS_TIME_INVALID':
      return 'Informe remoto antiguo o fecha incompatible. Consulta rechazada.';
    case 'ADDRESS_MISMATCH':
    case 'ADDRESS_INVALID':
      return 'La direccion consultada no coincide con la respuesta.';
    case 'ADDRESS_NETWORK_MISMATCH':
    case 'ADDRESS_TIP_MISMATCH':
      return 'La respuesta no coincide con la red o el bloque declarado.';
    case 'ADDRESS_AMOUNT_INVALID':
    case 'ADDRESS_HISTORY_INVALID':
    case 'ADDRESS_HISTORY_ORDER_INVALID':
      return 'Movimientos o cantidades remotas incoherentes. Rechazados.';
    default:
      return 'Respuesta no aceptada ($code). No se muestran saldos.';
  }
}
