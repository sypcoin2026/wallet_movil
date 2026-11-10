# Validación local de la base v0.6.1

## Entorno y comandos

La copia de seguridad original se validó el 10/11/2026 con Flutter 3.47.9 y Dart 3.13.7: `flutter analyze` sin incidencias y `flutter test --reporter expanded` con **95 PASS, 0 FAIL**.

Para reproducir las comprobaciones desde un clon:

```bash
bash scripts/validar.sh
```

El script usa el lockfile existente y ejecuta análisis y pruebas. Para un SDK fuera de PATH:

```bash
SYPC_FLUTTER_BIN=/ruta/al/flutter/bin/flutter bash scripts/validar.sh
```

Flutter y Android SDK se instalan fuera del repositorio. Flutter puede regenerar `android/local.properties` con las rutas locales cuando haga falta; ese archivo permanece ignorado. No hay que copiar una configuración de otra máquina ni claves de firma.

No se generan APK ni se instala nada en un móvil. Las pruebas usan SharedPreferences simulado y fetchers falsos, no nodos SYPC.

## Vectores criptográficos

Los fixtures contienen los 30 casos auditados del candidato nativo, más dos P2S generados con sigma-state 6.0.7 que tienen 384 y 5.584 caracteres. Los 32 se comprobaron con el candidato nativo: **10 positivos y 22 rechazos correctos**. Las pruebas Dart usan esos resultados como oráculo independiente.

`tool/GenerateNativePublicVectors.java` permite regenerar los dos P2S si se dispone del classpath nativo correspondiente. No se incluye ni descarga Core como parte de las pruebas de Flutter. `tool/generate_independent_envelopes.py` regenera los negativos de hashlib sin el codificador Dart.

Las pruebas de P2S demuestran interoperabilidad de la codificación, no validación de scripts en Dart. Tampoco demuestran fondos, recompensa, propiedad o consenso.

## Pendiente

No se han probado un teléfono físico, una API real ni la integración con Core. La configuración Android y su identificador se conservan, pero un clon nuevo no incluye la clave debug original. La compilación o instalación requiere autorización posterior.
