# Política offline de autenticación

## Principios

- Firebase Auth conserva la sesión segura.
- SQLite no se borra por fallos de Firebase.
- Cerrar sesión no borra inspecciones locales, fotografías, PDF ni borradores.
- Si nunca existió una sesión válida, no se permite entrar a LINERB.
- Si existía una sesión previamente validada y Firebase falla temporalmente, se permite uso local con el último perfil activo cacheado.

## Cache local permitido

`SharedPreferencesAuthSessionStorage` guarda solo el último `UserProfile` válido:

- uid
- displayName
- email
- role
- active
- createdAt
- updatedAt

No guarda contraseñas, tokens, fotografías, rutas locales, PDF, borrador ni identificadores sensibles.

## Modo degradado

Cuando Firebase no está disponible:

1. `AuthController.restoreSession()` intenta leer Firebase Auth.
2. Si falla, consulta el último perfil válido.
3. Si existe y está activo, permite uso local.
4. Si no existe, muestra login/error genérico.

## Datos locales

SQLite continúa como fuente operativa principal. El dashboard sigue alimentándose desde SQLite. El borrador permanece local y las fotografías se mantienen únicamente en el dispositivo donde se tomaron.
