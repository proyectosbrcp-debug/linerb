# Flujo runtime de migración

Este documento describe cuándo y cómo LINERB activa SQLite y migra datos V1.

## Secuencia de arranque

```text
main()
  -> WidgetsFlutterBinding.ensureInitialized()
  -> AppDependencies.initialize()
      estado = initializing
      abrir SQLite
      ejecutar migración V1
      hidratar memoria para avance
      estado = ready
  -> runApp()
```

Si ocurre error o timeout:

```text
estado = degraded
registrar error interno
continuar con runApp()
usar SharedPreferencesStorage como fallback
```

## Migración ejecutada una sola vez por arranque

`AppRuntimeInitializer.initialize()` memoiza su resultado.

Si se llama más de una vez en el mismo proceso, retorna el resultado existente sin repetir la operación.

Además, `V1DataMigrationService` consulta:

```text
migration_metadata[v1_shared_preferences]
```

Si ya está completo, no vuelve a migrar datos.

## Idempotencia

La migración evita duplicados con:

- IDs estables por contenido;
- `source_key` único para inspecciones V1;
- marca de metadata al terminar correctamente.

Ejecutar la migración múltiples veces no duplica inspecciones.

## Fallback

Los storages de fallback deciden en runtime:

```text
si migration_metadata == completed:
  usar SQLite
si no:
  usar SharedPreferencesStorage
```

Si SQLite no está disponible, la consulta de metadata falla y el fallback usa V1.

## Datos V1 conservados

La migración lee, pero no elimina:

- `historial_inspecciones`
- `borrador_usuario`
- `borrador_tipoLinea`
- `borrador_seleccionLinea`
- `borrador_responsable`
- `borrador_puntoReferencia`
- `borrador_estadoLinea`
- `borrador_hallazgos`

El cache de catálogos también permanece en V1:

- `json_troncales_cache`
- `json_ramales_cache`

## Comportamiento ante fallos

### SQLite no abre

- estado `degraded`;
- fallback V1;
- usuario puede continuar.

### Migración falla parcialmente

- estado `degraded`;
- metadata no se marca como completa;
- fallback V1;
- claves V1 intactas.

### Guardado final falla

- no se borra el borrador;
- el usuario no pierde el borrador existente.
