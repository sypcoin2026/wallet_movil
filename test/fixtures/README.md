# Procedencia de vectores públicos v0.6.1

`native_address_vectors.tsv` conserva los 30 casos de la auditoría pública del candidato prefix48 de 10/11/2026 y añade dos P2S largos generados con `tool/GenerateNativePublicVectors.java`.

Los 32 se ejecutaron contra el candidato original `SypcPrefix48Candidate.java`: 10 positivos y 22 rechazos correctos. Los P2S nuevos son conjunciones nativas de 8 y 120 proposiciones sobre un punto público conocido, sin generación de claves. Miden 384 y 5.584 caracteres Base58.

Proveedor: sigma-state_2.12 6.0.7.jar, SHA-256 `390bc91cb6201c26ae5309fd25c96f3e427343ed9b75968a2db96f365ca7d31b`. Candidato original: SHA-256 `f7879149b970e1f6365bb63c75f546c744ae844977b099982fe761d16f2eefde`.

`independent_envelopes.json` procede de Python hashlib, sin el codificador Dart. Incluye Blake2b-512 truncado y doble SHA-256, tamaño excesivo, tipo cero y un sobre P2S con contenido no interpretado. Ese último solo debe marcar `encodingValid`, nunca `scriptValidated`.

La app no replica el analizador nativo de ErgoTree. Las pruebas P2S confirman la codificación, sin atribuir a Dart validación de scripts. Los errores nativos de campo y curva se agrupan como `PUBLIC_KEY_CURVE`: ambos se rechazan.
