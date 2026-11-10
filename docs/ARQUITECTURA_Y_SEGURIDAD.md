# Arquitectura actual — v0.6.1

La app es una cartera experimental de observación. No crea ni custodia claves y no implementa firma, difusión de transacciones o escrow.

## Fronteras

1. `SypcAddressValidator` inspecciona la codificación pública de la red privada SYPC sin depender de la interfaz. Usa PointyCastle para Blake2b-256 y puntos secp256k1.
2. `SypcWatchBook` aplica esa validación a nuevas altas. Al leer respaldos v1 conserva los candidatos admitidos por v0.6 y muestra revisión si la validación actual falla.
3. `SypcWatchStore` guarda únicamente metadatos públicos en SharedPreferences, bajo la clave `sypc_watch_book_v1`. SharedPreferences no es una caja fuerte.
4. Los clientes existentes hacen consultas HTTPS manuales a un formato de pasarela definido por la app. Validan identidad declarada, estructura, antigüedad y coincidencia entre reportes. Eso no prueba una cadena canónica.
5. `SypcAddressReportGuard` valida cada campo monetario con el parser común y exige un reporte correspondiente a la dirección y tip solicitados.
6. La UI muestra advertencias, bloquea QR y consultas para candidatos antiguos inválidos y mantiene deshabilitadas las operaciones monetarias.

## Direcciones y cantidades

Se admiten sobres de red 48 con cabeceras P2PK 49, P2SH 50 y P2S 51. El checksum utiliza los primeros cuatro bytes de Blake2b con salida de 32 bytes. P2PK exige un punto comprimido válido. P2SH tiene contenido de 24 bytes. **P2S no incluye análisis canónico ni semántico del script.**

Los presupuestos defensivos son 6.000 caracteres Base58 y 4.096 bytes de contenido. La capacidad del QR es una restricción de presentación separada, que no limita la importación del texto público.

La escala es 10^9 unidades por SYPC y el máximo local es 28.000.000 SYPC. Se limita cada cantidad individual; categorías confirmadas, pendientes e inmaduras pueden solaparse, y los movimientos históricos no representan suministro simultáneo.

## Verificación pendiente

No hay verificación independiente de UTXO, consenso, propiedad, recompensa minera, madurez o finalidad. Un servidor puede mentir con una cantidad dentro del rango. No se implementó un cliente ligero, autenticación de reportes o pinning de un servicio concreto. Se conserva la validación TLS del sistema y el bloqueo de redirecciones.

La minería y Core son procesos y proyectos separados. Sus contratos y reglas no se modifican desde la cartera. El modo fiat y SecureTrade son diseño de interfaz: una declaración de pago nunca debe liberar dinero.
