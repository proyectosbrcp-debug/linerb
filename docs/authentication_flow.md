# Flujo de autenticación

## Inicio de aplicación

1. `main.dart` inicializa Firebase Core y dependencias existentes.
2. `LinerbApp` abre `AuthGate`.
3. `AuthGate` llama `AuthController.restoreSession()`.
4. Si Firebase Auth tiene sesión y `users/{uid}` existe activo, se abre LINERB.
5. Si no hay sesión, se muestra `LoginPage`.
6. Si el perfil está inactivo, se bloquea el acceso.
7. Si Firebase no está disponible, solo se permite modo local si existe un perfil previamente validado.

## Inicio de sesión

1. Usuario ingresa correo y contraseña.
2. `LoginPage` llama `AuthController.signIn()`.
3. `AuthController` usa `AuthRepository`, sin importar Firebase directamente.
4. Firebase Auth valida credenciales.
5. Se carga `users/{uid}` desde Firestore.
6. Si el perfil está activo, se guarda el último perfil válido localmente y se entra a LINERB.

No existe botón de crear cuenta. Los usuarios se crean desde Firebase Console o una herramienta administrativa futura.

## Recuperación de contraseña

`LoginPage` permite solicitar recuperación con correo. La respuesta al usuario es genérica para no revelar si el correo existe.

## Cierre de sesión

`AuthController.signOut()` cierra la sesión de Firebase Auth y limpia el perfil cacheado. No borra SQLite, fotografías locales, PDF, borrador ni claves V1.

## Mensajes de error

La UI no muestra códigos Firebase, stack traces ni detalles técnicos de seguridad. Los errores se registran de forma interna con `AppLogger`.
