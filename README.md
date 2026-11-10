# SYPC Wallet — Android experimental

Repositorio de trabajo de la cartera móvil de SYPcoin. Base actual: **v0.6.1+7**, Flutter y Dart, red privada `SypPrivateV30`.

La aplicación es **watch-only**: gestiona direcciones públicas y etiquetas, conserva una libreta local y permite consultas manuales a una pasarela HTTPS compatible. No genera ni custodia claves, no firma, no envía transacciones y no opera escrow.

## Estado actual

- Validación de direcciones Base58 de SYPC: prefijo de red 48, checksum Blake2b-256, tipos P2PK/P2SH/P2S y puntos secp256k1 para P2PK.
- P2S: se valida la codificación; **el script ErgoTree no se valida**.
- Libreta, selección y etiquetas persistidas; importación/exportación de respaldos públicos v1.
- Direcciones antiguas inválidas conservadas con aviso de revisión, sin QR ni consultas remotas.
- Cantidades individuales limitadas a **28.000.000.000.000.000 unidades base**; 1 SYPC = 1.000.000.000 unidades. Los saldos remotos son declaraciones del servidor y **no se verifican por consenso**.
- Envíos, firma, difusión, custodia de claves y escrow permanecen deshabilitados.

**No está lista para distribución, mainnet ni manejo de fondos reales.** No introduzcas semillas, contraseñas o claves privadas.

## Desarrollo y validación

La base se comprobó con Flutter **3.47.9**, Dart **3.13.7** y Android SDK instalado por separado. `pubspec.lock` conserva las dependencias resueltas, con PointyCastle **4.0.0** fijado exactamente.

```bash
git clone https://github.com/sypcoin2026/wallet_movil.git
cd wallet_movil
bash scripts/validar.sh
```

El script ejecuta `flutter pub get --enforce-lockfile`, `flutter analyze --no-pub` y `flutter test --no-pub`. También puede indicarse otro ejecutable mediante `SYPC_FLUTTER_BIN`. No construye APK ni se conecta a nodos SYPC.

La validación v0.6.1 registra **95 pruebas Flutter PASS** y **32/32 vectores nativos PASS**. Las instrucciones y límites de esas comprobaciones están en [Validación local](docs/VALIDACION_LOCAL.md) y en el [informe de seguridad](docs/INFORME_SYPC_WALLET_V061_SEGURIDAD.md).

## Estructura

| Ruta | Contenido |
|---|---|
| `lib/domain/` | Validación, políticas, libreta y modelos de reportes |
| `lib/services/` | Persistencia pública y consultas HTTPS existentes |
| `lib/pages/`, `lib/main.dart`, `lib/splash/` | Interfaz Flutter |
| `test/`, `test/fixtures/` | Regresiones y vectores públicos |
| `tool/` | Generadores de fixtures independientes |
| `android/` | Proyecto Android y Gradle wrapper |
| `docs/` | Arquitectura, validación y seguridad |

El identificador Android sigue siendo `com.sypcoin.sypc_wallet`. La configuración de firma se conserva; las claves y los almacenes de firma no pertenecen al repositorio. Un clon nuevo no incluye la clave debug original y no debe reemplazar una instalación existente sin gestionar esa identidad por separado.

Este repositorio contiene el código y los recursos necesarios para continuar el desarrollo. Los SDK, cachés, APK, datos de la app instalada, copias históricas y evidencias con rutas locales se conservan fuera de Git.
