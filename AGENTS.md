# Trabajo en SYPC Wallet

- No uses subagentes salvo que el usuario cambie expresamente esta instrucción.
- Mantén el carácter experimental watch-only. No habilites claves, semillas, firma, transferencias, difusión ni escrow como parte de tareas ajenas a esas funciones.
- No arranques nodos, minería ni modifiques GPU, Core, consenso, Autolykos, génesis o contratos.
- No generes ni instales APK, publiques releases o cambies el identificador o la firma Android sin autorización explícita para esa tarea.
- No leas claves privadas, frases semilla ni material de firma. No añadas datos de wallets, SDK, certificados, credenciales o cachés a Git.
- Red de esta base: SypPrivateV30, prefijo 48, cabeceras 49/50/51. Blake2b-256 exige salida configurada a 32 bytes, no truncar Blake2b-512 ni usar doble SHA-256.
- P2S solo tiene codificación comprobada; no afirmes validación canónica de ErgoTree, propiedad o fondos. Los reportes remotos no prueban consenso.
- Conserva las entradas y etiquetas de los respaldos v1; los candidatos antiguos inválidos deben seguir visibles con estado de revisión. No los borres silenciosamente.
- Comprueba cada cantidad individual declarada contra 28.000.000.000.000.000 unidades base mediante BigInt; no sumes categorías monetarias superpuestas.
- Conserva pubspec.lock y las versiones fijadas salvo necesidad justificada. No cambies controles de TLS, identidad de red o timestamps para hacer pasar una prueba.
- Para validar, usa scripts/validar.sh con Flutter 3.47.9 o documenta las diferencias del entorno. Ejecuta comprobaciones proporcionales y evita repeticiones sin causa.
- Haz cambios en este repositorio; las copias originales y la wallet instalada quedan fuera de la tarea. No hagas push o publicación de cambios posteriores sin autorización o sin que forme parte expresa de la tarea.
