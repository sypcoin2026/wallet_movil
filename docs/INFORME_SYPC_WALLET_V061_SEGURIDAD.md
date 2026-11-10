# Informe público — SYPC Wallet v0.6.1

Fecha de la corrección: 10/11/2026. Versión: **0.6.1+7**. Esta es una síntesis portable del informe local; las evidencias completas y los originales permanecen conservados en el equipo del propietario.

## Cambios

Se sustituyó la validación superficial de Base58 por un validador independiente de la UI: red 48, cabeceras 49/50/51, checksum Blake2b-256 configurado a 32 bytes, longitud y estructura por tipo y puntos comprimidos secp256k1 para P2PK. Se fijó PointyCastle 4.0.0 y se conservaron las versiones existentes del lockfile.

Los P2S reconocen únicamente una codificación válida: el script ErgoTree **no está validado**. Los presupuestos defensivos son 6.000 caracteres y 4.096 bytes de contenido, sin presentarlos como reglas de consenso.

La libreta conserva etiquetas, selección, origen HTTPS, esquema v1 y la clave de persistencia. Los candidatos antiguos inválidos permanecen visibles para revisión y exportación, sin QR ni consultas remotas. Los respaldos admiten hasta 131.072 caracteres para poder conservar P2S largos.

El parser común limita cada saldo y cada movimiento declarado al suministro de **28.000.000.000.000.000 unidades base**. Usa BigInt, rechaza negativos y formatos no canónicos y no suma categorías que puedan solaparse.

## Evidencia económica

Se inspeccionó el código público del laboratorio Core privado, revisión `dbc79c323c002fe9d5146bc5feba5fde138661d6`. La ruta `SypV30NativeProfile` → `SypV29PrivateGenesisCandidate` toma el presupuesto de `SypV20GenesisInventory`: 24.268.230 + 2.696.470 + 210.000 + 825.300 = 28.000.000 SYPC, con 1.000.000.000 unidades por SYPC. `SypCurrencyDisplay` confirma nueve decimales.

Existe una especificación antigua de 21 millones, que no se utilizó para el presupuesto privado V30. Este respaldo es estático; no demuestra qué cadena ejecuta un nodo. No se arrancó ni consultó ningún nodo para esta corrección.

## Validación

| Comprobación de la corrección | Resultado |
|---|---|
| Flutter analyze | Sin incidencias |
| Flutter test | **95 PASS, 0 FAIL** |
| Candidato nativo sobre 32 vectores públicos | **32/32 PASS** |
| Archivos inventariados del proyecto original | **73/73 idénticos** |
| APK nueva o instalación | Ninguna |

Entorno: Flutter 3.47.9, Dart 3.13.7. La pasada final completa se ejecutó una sola vez, tras corregir un callback de un test de widgets. Se conservaron los 42 casos anteriores, sustituyendo positivos ficticios por datos válidos, y se añadieron 53 casos.

La reproducción focalizada confirmó que el original admitía una dirección Ergo mainnet y una cantidad mayor al máximo. La corrección rechaza ambos y mantiene la dirección SYPC legítima y el máximo exacto. También se prueban P2SH, P2S largo, Bitcoin, checksums alterados, tipos desconocidos, puntos inválidos, formatos monetarios manipulados, persistencia y bloqueo de firma/transferencias.

El proveedor nativo sigma-state_2.12 6.0.7.jar conserva el SHA-256 `390bc91cb6201c26ae5309fd25c96f3e427343ed9b75968a2db96f365ca7d31b`. Las direcciones largas se generaron en la biblioteca nativa, sin generar claves. El original del candidato tiene SHA-256 `f7879149b970e1f6365bb63c75f546c744ae844977b099982fe761d16f2eefde`.

El diff local de la corrección tiene SHA-256 `9fb3f1d451a07be5c98787084d7942e7eed857992ba67906406ba98d97a9b5e3`. El repositorio parte del mismo código Dart, pruebas y dependencias de esa copia validada; la preparación para Git añade documentación portable y reglas de exclusión.

## Mitigado

- Nuevas direcciones de otra red, tipo desconocido, checksum incorrecto o P2PK inválido.
- Uso de validación superficial en consultas y reportes.
- Presentación de candidatos antiguos inválidos sin un estado de revisión.
- Cantidades individuales imposibles en saldos y movimientos.
- Rechazo arbitrario de P2S solo por superar 110 caracteres.

## Pendiente y límites

- Analizador canónico y semántico de ErgoTree P2S.
- Consenso, UTXO, propiedad, madurez, recompensa minera, finalidad y capacidad de gasto.
- Autenticación de declaraciones, API real y diseño de cliente ligero.
- Independencia temporal: la ventana compara con el reloj local, sin autenticar timestamps del servidor.
- Identidad del servicio, pinning TLS y revisión de destino/DNS en una fase posterior. La validación TLS del sistema, HTTPS, límites y bloqueo de redirecciones se mantienen.
- Privacidad de metadatos públicos en SharedPreferences, que no es una caja fuerte.
- Fallo del decodificador original de Core para prefijo 48: esta corrección no modifica Core.
- Revisión completa de dependencias, pruebas físicas Android y pruebas de integración.

Un servidor malicioso todavía puede mentir con cantidades dentro del rango. No se introdujeron checkpoints permisivos, hashes inventados, badCertificateCallback, confianza temporal ciega ni verificaciones ficticias.

## Estado

Base de desarrollo experimental watch-only. Identificador y configuración de firma Android conservados, sin claves en Git. No hay custodia, firma, envío ni escrow operativo. **No se declara lista para distribución, mainnet ni manejo de fondos reales.** La actualización de este repositorio de código no implica generar o distribuir APK.
