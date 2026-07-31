# Política de reintentos de sincronización

Servicio: `SyncRetryPolicy`.

La política usa backoff con jitter inyectable:

- intento 1: 30 segundos + jitter;
- intento 2: 1 minuto + jitter;
- intento 3: 2 minutos + jitter;
- intento 4 o más: 5 minutos + jitter;
- máximo: 10 minutos.

Reglas:

- El contador se reinicia de forma efectiva al completarse la operación y salir de la cola.
- No se crean timers múltiples para la misma ventana: el coordinador cancela el timer anterior antes de programar otro.
- `permission` y `authentication` no deben entrar en reintento agresivo.
- `network`, `unavailable`, `timeout`, `remoteStorage`, `rateLimited` y `unknown` se tratan como transitorios.
- La conectividad es señal, no garantía.

El jitter es determinista por defecto y puede inyectarse en pruebas.
