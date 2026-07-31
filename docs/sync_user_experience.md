# Experiencia de usuario de sincronización

Widgets:

- `SyncStatusIndicator`
- `SyncStatusPage`

Ubicación:

- Pantalla principal.
- Dashboard.

Estados visibles:

- Sincronizando...
- Actualizado
- N cambios pendientes
- Sin conexión
- Sesión requerida
- Error temporal
- Permiso insuficiente
- Conflicto pendiente

Principios:

- Indicador discreto.
- No bloquea navegación.
- Usa texto además de icono/color.
- No muestra stack traces.
- No muestra códigos Firebase.
- No muestra payloads ni datos sensibles.
- El botón "Sincronizar ahora" no reemplaza la sincronización automática.

Dashboard:

- Muestra estado de sincronización, última actualización y pendientes.
- Sigue consultando SQLite mediante `DashboardController`.
- No consulta Firestore.

Política offline:

- La inspección se guarda localmente.
- La cola conserva cambios pendientes.
- Un fallo remoto no invalida la inspección local.
- El estado central muestra pendientes o falta de conexión.
