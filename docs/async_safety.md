# Seguridad asíncrona en LINERB V1

## Alcance del segundo bloque de Fase 1

Este bloque protege las continuaciones asíncronas que actualizan un `State` o usan su `BuildContext` después de un `await`. No cambia el flujo, los mensajes, la navegación ni la arquitectura de V1.

Se añadieron comprobaciones `if (!mounted) return;` antes de:

- Actualizar la selección de línea con catálogos remotos, caché o assets.
- Restaurar un borrador en controladores y estado de pantalla.
- Actualizar la pantalla después de volver de la cámara.
- Mostrar mensajes o actualizar coordenadas después de consultar permisos y GPS.
- Continuar el guardado desde el resumen después de generar el PDF.
- Mostrar la confirmación y navegar después de persistir historial y borrar el borrador.
- Publicar en pantalla el historial cargado desde almacenamiento.

Estas guardas sólo cambian el comportamiento cuando el widget ya fue eliminado del árbol. En ese caso se abandona la actualización visual para evitar `setState() called after dispose`, navegación desde un contexto inválido o acceso a un `ScaffoldMessenger` desmontado.

## Riesgos identificados fuera del alcance

| Riesgo | Motivo para no corregirlo en este bloque |
|---|---|
| Las llamadas HTTP no tienen timeout. | Requiere definir política de red, error y reintento; alteraría el comportamiento observable del catálogo. |
| Cámara, GPS, preferencias, lectura de archivos e impresión no tienen manejo uniforme de excepciones. | Añadir mensajes o rutas alternativas cambia el flujo visible y corresponde al siguiente bloque de estabilización. |
| `guardarBorradorLocal()` se inicia sin `await`. | Esperarlo modificaría el orden y tiempos del botón actual; debe resolverse junto con la política de persistencia. Sus escrituras no usan UI después de `await`. |
| El botón de confirmación puede iniciar más de una operación simultánea. | Deshabilitarlo o introducir estado de progreso cambia la interacción visible. |
| La generación de PDF usa datos del `State` durante operaciones largas. | Separarla del widget requiere extracción de responsabilidades, expresamente fuera de este bloque. La continuación que guarda o navega sí queda protegida. |
| Las escrituras múltiples de `SharedPreferences` no son transaccionales. | Corregirlo requiere cambiar el modelo de persistencia, previsto para una fase posterior. |

## Criterio de validación

- `flutter analyze` no debe reportar `use_build_context_synchronously` en `main.dart`.
- La suite de caracterización V1 debe continuar pasando sin cambios.
- El diff no debe incluir modificaciones de textos, estilos, rutas o estructura de pantallas.
