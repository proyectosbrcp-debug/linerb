# LINERB V2 - Sprint 4.4: autenticación y perfiles operativos

## Objetivo

Sprint 4.4 agrega autenticación segura con Firebase Auth y perfiles operativos en Firestore para preparar una sincronización controlada futura de datos estructurados.

No se activó sincronización automática. SQLite continúa como fuente operativa principal y Firestore permanece como fuente remota compartida para datos estructurados.

## Dependencia agregada

- `firebase_auth`: autenticación por correo y contraseña, sesión segura administrada por Firebase Auth, cierre de sesión y recuperación de contraseña.

No se agregó Firebase Storage ni paquetes de inyección de dependencias.

## Componentes creados

### Modelos

- `UserProfile`: uid, displayName, email, role, active, createdAt, updatedAt.
- `UserRole`: administrator, supervisor, inspector, viewer.
- `AuthState` / `AuthStatus`: initial, loading, authenticated, unauthenticated, disabled, error.

### Contratos

- `AuthRepository`: sesión actual, login, logout y recuperación.
- `UserProfileRepository`: lectura de perfil operativo por uid.
- `AuthSessionStorage`: cache local mínimo de último perfil válido.

### Implementaciones

- `FirebaseAuthRepository`: delega en Firebase Auth.
- `FirestoreUserProfileRepository`: lee `users/{uid}` desde Firestore.
- `SharedPreferencesAuthSessionStorage`: guarda únicamente el último perfil válido; no guarda contraseñas ni tokens.
- `UnavailableAuthRepository` / `UnavailableUserProfileRepository`: fallback seguro cuando Firebase no está disponible.

### Controller

- `AuthController`: independiente de Widgets, BuildContext, Navigator y Firebase directo.
- Controla restore, sign in, sign out y reset password con mensajes genéricos.

### UI mínima

- `AuthGate`: decide entre login, bloqueo por usuario inactivo o entrada normal a LINERB.
- `LoginPage`: correo, contraseña, mostrar/ocultar contraseña, iniciar sesión y recuperar contraseña.

## Integración mínima

- `LinerbApp` inicia en `AuthGate`.
- `InicioPage` queda como compatibilidad interna hacia `AuthGate`, sin credenciales embebidas.
- `SeleccionLineaPage` recibe opcionalmente `UserProfile`.
- `created_by` y `updated_by` usan el uid autenticado cuando existe sesión válida.

## Límites respetados

- No se modificó el flujo de inspección salvo la identificación del usuario autenticado.
- No se activó `SyncWorker` automático.
- No se migró el borrador a remoto.
- No se sincronizan fotografías, rutas locales ni PDF.
- No se agregó registro público.
- No se agregaron credenciales embebidas.
