# Sprint 4.9 - Pulido UX, consistencia visual y accesibilidad

## Objetivo

Fortalecer la experiencia de uso en teléfonos Android de campo sin cambiar lógica funcional, navegación, persistencia, sincronización, PDF, fotografías ni reglas de negocio.

## Auditoría realizada

Pantallas revisadas:

- Login.
- Inicio y selección de línea.
- Registro de inspección.
- Resumen de inspección.
- Historial.
- Avance.
- Dashboard y detalles.
- Estado de sincronización.

Hallazgos principales:

- Existían valores visuales repetidos para espaciado, color y altura de botones.
- Algunos estados vacíos no tenían un patrón común reutilizable.
- Algunos loaders usaban estructuras distintas entre pantallas.
- Login, finalización de inspección y confirmación de guardado podían recibir doble toque durante operaciones críticas.
- El estado del semáforo en Avance dependía demasiado del color; se agregó texto, icono y semántica.
- En pantallas pequeñas con escalado de texto alto, los estados vacíos y Avance podían desbordarse.
- Había textos visibles con mojibake en las superficies ajustadas.
- El indicador de sincronización podía quedar con objetivo táctil menor al mínimo recomendado.

## Cambios aplicados

### Constantes visuales

Se creó `lib/core/theme/ui_constants.dart` con:

- Espaciados de 4, 8, 12, 16, 24 y 32.
- Radios base.
- Alturas mínimas de botones.
- Colores LINERB usados por las pantallas ajustadas.
- Estilos de título y sección.

### Widgets reutilizables

Se crearon:

- `LinerbEmptyState`: estado vacío con icono, título, mensaje y acción opcional. Es desplazable para evitar overflow con texto grande.
- `LinerbLoadingState`: loader con mensaje descriptivo.

### Pantallas ajustadas

- Login:
  - Autofill para correo y contraseña.
  - Acciones de teclado.
  - Tooltip para mostrar/ocultar contraseña.
  - Estado de carga y bloqueo contra doble envío.
  - Mensaje de error genérico con semántica de región viva.

- Historial:
  - Loader reutilizable.
  - Estado vacío reutilizable.
  - Corrección de textos visibles con tildes.

- Avance:
  - Semáforo con icono, texto y etiqueta semántica.
  - Layout desplazable para soportar teléfonos pequeños y texto escalado.
  - Estado vacío reutilizable.
  - Corrección de textos visibles con tildes.

- Registro de inspección:
  - Alturas mínimas unificadas en botones críticos.
  - Protección contra doble toque al agregar hallazgo y al finalizar.

- Resumen:
  - Protección contra doble toque al confirmar y guardar.
  - Altura mínima unificada del botón principal.

- Sincronización:
  - Objetivo táctil mínimo en indicador de estado.
  - Botón manual deshabilitado mientras hay sincronización activa.
  - Región semántica para el estado visible.

## Límites respetados

- No se modificó SQLite.
- No se modificó Firestore.
- No se modificó autenticación ni permisos.
- No se modificó el diseño PDF aprobado.
- No se modificó política de fotografías.
- No se agregó Firebase Storage.
- No se cambiaron reglas de dashboard ni filtros.
- No se implementaron tareas con la aplicación cerrada.

## Pendientes no bloqueantes

- Completar una normalización gradual de textos antiguos que aún no fueron tocados por este sprint.
- Agregar golden tests cuando el entorno tenga infraestructura estable para capturas.
- Revisión manual en dispositivos Android físicos con brillo alto y uso con guantes.
