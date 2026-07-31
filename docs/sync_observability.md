# Observabilidad segura de sincronización

Fuente única: `AutomaticSyncCoordinator`.

Datos observables:

- fase actual;
- última sincronización exitosa;
- último intento;
- duración;
- enviados;
- descargados;
- aplicados;
- pendientes;
- fallidos;
- conflictos;
- próxima fecha de reintento;
- conectividad declarada;
- sesión;
- perfil;
- permisos;
- rol;
- métricas resumidas.

Persistencia local:

- Se usa `migration_metadata` con la clave `sync_status_snapshot_v1`.
- No se agregó tabla nueva.
- No se subió versión de SQLite.
- No se guardan payloads, tokens, rutas, fotos, PDF ni mapas.

Métricas locales:

- ciclos totales;
- ciclos exitosos;
- ciclos parciales;
- ciclos fallidos;
- duración promedio;
- último éxito;
- último fallo;
- pendientes actuales;
- máximo de pendientes observado;
- reintentos;
- conflictos;
- modo ready/degraded.

Estas métricas no se sincronizan con Firestore.
