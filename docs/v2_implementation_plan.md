# LINERB V2 — Plan de implementación por fases

## Principios de ejecución

- Mantener V1 operativa durante toda la migración.
- Proteger comportamiento con pruebas antes de mover responsabilidades.
- Separar persistencia, plugins y reglas de negocio de la interfaz de forma incremental.
- Realizar migraciones de datos verificables y reversibles.
- Evitar un cambio simultáneo de arquitectura, UI, almacenamiento y backend.
- Definir criterios de salida medibles para cada fase.

## Fase 0 — Congelar y caracterizar V1

Objetivo: crear una línea base verificable antes de modificar producción.

Acciones:

1. Mantener `docs/v1_behavior_matrix.md` como contrato de comportamiento observado.
2. Mantener una lista explícita de limitaciones conocidas que no deben confundirse con regresiones.
3. Crear pruebas de caracterización para lógica y widgets que no dependan de plugins reales.
4. Definir smoke tests manuales para login válido, fallback de catálogo, GPS, cámara y PDF.
5. Ejecutar `flutter analyze` y `flutter test` como controles mínimos.
6. Guardar muestras anonimizadas de `historial_inspecciones` y borrador antes de diseñar migraciones.
7. Definir oficialmente plataformas objetivo de V2.

Criterio de salida:

- Matriz V1 revisada.
- Suite mínima reproducible.
- Riesgos conocidos documentados.
- Ningún cambio funcional o visual en producción.

## Fase 1 — Estabilización crítica de V1

Objetivo: eliminar riesgos de plataforma y pérdida inmediata sin rediseñar la experiencia.

Acciones:

1. Completar permisos y descripciones de cámara, ubicación y red en las plataformas soportadas.
2. Configurar identificadores definitivos y firma de release.
3. Añadir estados explícitos de carga, error y reintento al catálogo.
4. Incorporar timeouts y manejo consistente de excepciones.
5. Copiar fotos a almacenamiento permanente administrado por la aplicación.
6. Guardar la inspección independientemente de generar o imprimir el PDF.
7. Evitar dobles confirmaciones y llamadas a `setState` después de desmontar widgets.
8. Liberar todos los controladores y recursos.

Criterio de salida:

- Builds release válidos en las plataformas objetivo.
- Una falla de PDF, cámara, GPS o red no provoca pérdida de la inspección.
- Pruebas de Fase 0 continúan pasando, salvo cambios de defectos aprobados y documentados.

## Fase 2 — Extracción de dominio e infraestructura

Objetivo: separar responsabilidades manteniendo el flujo visible.

Acciones:

1. Crear modelos tipados para línea, inspección, hallazgo, foto y reporte.
2. Introducir IDs estables, enums, coordenadas numéricas y fechas controladas.
3. Centralizar serialización y versionarla.
4. Extraer adaptadores para HTTP, preferencias, GPS, cámara, archivos, reloj e impresión.
5. Definir interfaces de repositorio y casos de uso.
6. Centralizar tema, constantes, mensajes y claves de almacenamiento.
7. Inyectar dependencias en lugar de acceder a plugins desde widgets.

Criterio de salida:

- La presentación no importa directamente `http`, `shared_preferences`, `geolocator`, `image_picker`, `dart:io`, `pdf` ni `printing`.
- Dominio y casos de uso tienen pruebas unitarias.
- El flujo V1 permanece reconocible y funcional.

## Fase 3 — Persistencia única y migración

Objetivo: reemplazar las fuentes divergentes por un repositorio local versionado.

Acciones:

1. Seleccionar una base local con transacciones y migraciones; Drift es la opción preferida para evaluación.
2. Diseñar tablas para inspecciones, hallazgos, adjuntos, líneas y reportes.
3. Crear migración idempotente desde `historial_inspecciones` y `borrador_*`.
4. Asignar IDs a registros V1 y marcarlos como legado cuando falten detalles irrecuperables.
5. Verificar conteos y contenido antes de marcar la migración como completada.
6. Conservar temporalmente una copia de las claves V1 para rollback.
7. Hacer que historial y avance consulten el mismo repositorio.
8. Añadir pruebas con datos válidos, incompletos, duplicados y corruptos.

Criterio de salida:

- Una sola fuente de verdad para inspecciones y avance.
- Migración repetible sin duplicar registros.
- Datos V1 preservados o marcados explícitamente como no recuperables.

## Fase 4 — Modularización de presentación y estado

Objetivo: dividir la aplicación por funcionalidades sin reescritura total.

Estructura objetivo inicial:

```text
lib/
  app/
    bootstrap/
    navigation/
    theme/
  core/
    errors/
    network/
    storage/
    platform/
  features/
    authentication/
    line_catalog/
    inspections/
    history/
    progress/
    reports/
```

Acciones:

1. Adoptar un mecanismo único de estado; Riverpod es la opción preferida para evaluación incremental.
2. Mover cada flujo a su feature con capas `domain`, `data` y `presentation` cuando aporten valor.
3. Dividir el formulario de inspección en componentes y estados manejables.
4. Incorporar edición y eliminación de hallazgos antes de confirmar.
5. Centralizar estados de carga, errores y mensajes.
6. Mantener rutas y comportamiento existentes hasta contar con cobertura suficiente.

Criterio de salida:

- Ninguna pantalla concentra presentación, persistencia y plugins.
- Los controladores son testeables sin `WidgetTester` cuando contienen reglas de negocio.
- No existe estado global mutable equivalente a `DatosApp`.

## Fase 5 — Catálogo, reportes y medios V2

Objetivo: robustecer los tres subsistemas con mayor dependencia externa.

Acciones:

1. Definir esquema y versión del catálogo remoto.
2. Validar completamente una descarga antes de reemplazar la caché activa.
3. Consolidar una única fuente publicable para los JSON y eliminar copias obsoletas.
4. Generar reportes desde inspecciones ya persistidas.
5. Persistir ID, versión, fecha y ubicación del reporte generado.
6. Corregir paginación y permitir regenerar, compartir o imprimir.
7. Comprimir imágenes, conservar metadatos y limitar consumo de memoria.
8. Añadir pruebas de contenido de PDF independientes del diálogo del sistema.

Criterio de salida:

- Catálogo offline-first validado y versionado.
- Reportes reproducibles desde datos persistidos.
- Fotos durables y asociadas por ID a sus hallazgos.

## Fase 6 — Seguridad, observabilidad y despliegue

Objetivo: preparar V2 para operación y distribución controlada.

Acciones:

1. Reemplazar credenciales embebidas por autenticación real o perfiles locales administrados.
2. Aplicar autorización efectiva por rol.
3. Definir sincronización y resolución de conflictos si se incorpora backend.
4. Registrar errores y métricas sin almacenar credenciales, coordenadas o fotos sensibles indebidamente.
5. Ejecutar pruebas smoke en builds release y dispositivos objetivo.
6. Migrar primero un grupo piloto y verificar datos antes de ampliar el despliegue.
7. Documentar rollback de aplicación y de almacenamiento.

Criterio de salida:

- Sin secretos reutilizables en el cliente.
- Release firmado y observable.
- Despliegue gradual con rollback probado.

## Orden de decisiones técnicas

Antes de incorporar dependencias nuevas se deben registrar decisiones breves para:

1. Plataformas oficialmente soportadas.
2. Base de datos y estrategia de migración.
3. Gestión de estado.
4. Navegación.
5. Autenticación y posible backend.
6. Almacenamiento y retención de fotografías.

El orden operativo recomendado es: proteger comportamiento, estabilizar riesgos, extraer límites, unificar datos, modularizar interfaz y finalmente ampliar seguridad/despliegue.
