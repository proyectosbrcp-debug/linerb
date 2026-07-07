# LINERB V1 — Matriz de comportamiento actual

## Propósito y alcance

Este documento congela el comportamiento observado en LINERB V1 antes de iniciar la evolución hacia V2. Describe lo que la aplicación hace actualmente, incluso cuando el comportamiento representa una limitación conocida.

Versión observada: `0.1.0+1`

Entrada de la aplicación: `lib/main.dart`

Persistencia local: `SharedPreferences` y estado estático en memoria

Navegación: `Navigator` con `MaterialPageRoute`

## Flujo general

1. La aplicación abre en la pantalla de login.
2. Un usuario válido accede a la selección de línea.
3. La selección carga catálogos remotos, desde caché o desde assets.
4. El usuario registra datos generales y cero o más hallazgos.
5. Los hallazgos agregados se guardan como borrador local.
6. La inspección pasa a una pantalla de resumen.
7. Al confirmar, primero se genera/imprime el PDF y después se guarda un resumen de la inspección.
8. Historial y avance se consultan desde la pantalla de selección.

## Matriz

| Área | Entrada o precondición | Comportamiento actual | Persistencia / salida | Validación de Fase 0 | Limitaciones conocidas |
|---|---|---|---|---|---|
| Login inicial | Abrir la aplicación | Muestra fecha local, usuario `SUPER` preseleccionado, campo de contraseña y botón `INICIAR`. | Ninguna sesión persistente. | Prueba widget: render inicial. | La pantalla usa una `Column` sin scroll y puede desbordarse en pantallas pequeñas o con teclado abierto. |
| Roles | Abrir selector de usuario | Ofrece únicamente `SUPER` e `INSPE`. | El nombre se pasa como `String` a las siguientes pantallas. | Prueba widget: opciones visibles. | Los roles no cambian permisos ni funcionalidades. |
| Credenciales | `SUPER` + `ECO01`, o `INSPE` + `MASA01` | Permite navegar a selección de línea. Cualquier otra combinación muestra `Usuario o contraseña incorrectos`. | Las credenciales están embebidas en el cliente; no hay backend ni sesión. | Prueba widget automatizada para rechazo; aceptación queda como smoke test manual para no disparar red real. | No constituye autenticación segura; una aplicación compilada puede revelar las claves. |
| Selección de tipo | Usuario autenticado | Permite escoger `Troncal` o `Ramal`. `Troncal` está seleccionado inicialmente. | Estado local del widget. | Caso manual y prueba del esquema de assets. | El valor inicial está fijado a `TRONCAL 1`; un catálogo que no lo contenga puede invalidar el dropdown. |
| Selección troncal | Tipo `Troncal` | Muestra un selector de troncal y otro de subtroncal. La selección se representa como `TRONCAL / SUBTRONCAL`. | Se pasa como texto a registro. | Caso manual. | El modelo es `Map<String, dynamic>` y supone que cada colección tiene al menos un elemento. |
| Selección ramal | Tipo `Ramal` | Muestra un selector con los ramales disponibles. | Se pasa como texto a registro. | Caso manual. | No existen IDs estables; el nombre funciona como identidad. |
| Catálogo remoto | Con conectividad y respuestas HTTP 200 en ambos endpoints | Consulta secuencialmente `https://linerb.web.app/troncales.json` y `ramales.json`; actualiza pantalla y caché. | Claves `json_troncales_cache` y `json_ramales_cache`. | No automatizado: requiere doble HTTP controlado en una fase posterior. | Sin timeout, validación de esquema, versión, fecha de expiración ni mensajes de error al usuario. |
| Caché de catálogo | Falla remoto y ambas claves existen | Decodifica la caché y continúa. | `SharedPreferences`. | Documentado; pendiente prueba con infraestructura inyectable. | Un JSON corrupto genera excepción y obliga al fallback de assets. |
| Catálogo integrado | Fallan remoto y caché | Lee `assets/data/troncales.json` y `assets/data/ramales.json`. Actualmente hay 12 grupos, 50 entradas troncales y 20 ramales. | Assets incluidos en la aplicación. | Prueba automatizada de estructura y cardinalidad. | Si también falla, la pantalla permanece en carga sin estado de error ni reintento. |
| Inicio de inspección | Selección válida | Abre registro con usuario, tipo y selección de línea. | Parámetros de ruta. | Caso manual. | No se crea todavía un ID de inspección ni una fecha de inicio persistente. |
| Datos generales | Pantalla de registro | Muestra línea, fecha actual, responsable, punto de referencia y estado operativo. El estado inicial es `Operativa`. | Estado local; algunos campos entran al borrador sólo al agregar un hallazgo. | Prueba widget mínima del estado inicial. | Sólo responsable es obligatorio al finalizar; punto de referencia puede quedar vacío. |
| Tipos de hallazgo | Registro activo | Ofrece corrosión, fuga, soportería, vegetación, válvulas, recubrimiento, terceros, erosión, socavación, instrumentación y acceso restringido. Corrosión inicia seleccionada. | Estado local. | Modelo y comportamiento documentados. | Los valores son cadenas literales; no existe catálogo tipado o versionado. |
| Detalle de hallazgo | Seleccionar vegetación, fuga, soportería o válvulas | Muestra un dropdown específico. Los demás tipos no tienen detalle adicional. | `detalle` de `HallazgoInspeccion`. | Caso manual. | La regla está codificada mediante comparaciones de texto dentro de la pantalla. |
| Coordenadas | GPS activo y permiso concedido | Obtiene una posición de alta precisión y completa latitud/longitud en campos de sólo lectura. | Se copia como texto al hallazgo. | Smoke test manual en dispositivo. | No captura precisión, hora ni proveedor; excepciones del plugin no están encapsuladas. |
| Validación de hallazgo | Pulsar `AGREGAR HALLAZGO A BORRADOR` | Exige latitud, longitud y descripción. Crea el hallazgo, limpia coordenadas, descripción y fotos, y muestra confirmación. | Lista en memoria más borrador local. | Prueba unitaria de representación del modelo; interacción completa manual. | No se puede editar ni eliminar un hallazgo agregado. |
| Borrador | Agregar un hallazgo | Guarda usuario, tipo, línea, responsable, referencia, estado y una lista JSON de hallazgos. | Claves `borrador_*` en `SharedPreferences`. | Matriz documental; la lógica privada y los plugins impiden una prueba estable sin refactor. | Sólo existe un borrador global. Las fotos se guardan como rutas y pueden desaparecer. |
| Recuperación de borrador | Abrir registro para la misma `seleccionLinea` | Restaura responsable, referencia, estado y hallazgos. | Lectura de claves `borrador_*`. | Caso manual. | Si la línea no coincide, el borrador queda almacenado pero oculto. Usuario y tipo guardados no se validan al restaurar. |
| Finalizar inspección | Responsable no vacío | Abre resumen con los datos y la lista de hallazgos. | Objetos pasados por constructor. | Caso manual. | Se permite finalizar sin hallazgos. Latitud y longitud generales suelen estar vacías porque los controles se limpian al agregar hallazgos. |
| Resumen | Inspección finalizada | Presenta fecha, responsable, usuario, línea, estado, hallazgos y observación general editable. | Estado de pantalla. | Caso manual. | Indica `FOTO 1 FOTO 2` aunque una o ambas fotos no existan y no muestra previsualizaciones. |
| Confirmación | Pulsar `CONFIRMAR Y GUARDAR` | Ejecuta `generarPdf()`, crea un `Inspeccion`, la agrega a memoria, la serializa en historial, elimina el borrador y vuelve dos rutas. | `DatosApp.inspecciones` y `historial_inspecciones`. | Historial y avance tienen pruebas separadas. | Si PDF/impresión falla, el guardado no continúa. No hay transacción ni protección contra doble pulsación. |
| Historial | Abrir `HISTORIAL` | Lee `historial_inspecciones`, decodifica cada JSON y lista línea, fecha y responsable. | `SharedPreferences`. | Prueba widget con almacenamiento simulado. | El registro definitivo no conserva hallazgos, coordenadas, fotos ni ID del informe. Un registro corrupto puede romper toda la carga. |
| Avance | Abrir `AVANCE` | Usa todas las líneas del catálogo y busca la última fecha en `DatosApp.inspecciones`. Calcula porcentaje y prioridad: nunca/rojo, hasta 15 días/verde, hasta 60/amarillo y mayor/rojo. | Sólo memoria del proceso actual. | Prueba widget del cálculo básico. | No lee el historial persistente. Después de reiniciar, todas las líneas aparecen como nunca inspeccionadas. |
| PDF | Confirmar resumen | Carga logo y dos imágenes de pie, crea un `pw.MultiPage`, añade datos generales, hallazgos, fotos y observación, y abre `Printing.layoutPdf`. | Flujo del sistema de impresión; no se conserva una relación estable con la inspección. | Smoke test manual; no se invoca el plugin en pruebas unitarias. | ID basado en milisegundos no persistido; texto de página fijado en `Página: 1`; generación acoplada al guardado. |
| Foto 1 / Foto 2 | Pulsar botón de cámara | Abre cámara con calidad 80 y conserva el `File` devuelto. Cada hallazgo admite como máximo dos fotos. | Ruta temporal en el hallazgo/borrador; bytes incluidos en PDF si la ruta aún existe. | Smoke test manual en dispositivo. | Métodos duplicados, sin copia permanente, metadatos, control de tamaño ni recuperación ante errores. |

## Fuentes de verdad actuales

| Información | Fuente actual |
|---|---|
| Catálogo activo | Estado local de `SeleccionLineaPage` |
| Caché de catálogo | `SharedPreferences` |
| Inspección en edición | Estado local de `RegistroInspeccionPage` |
| Borrador | `SharedPreferences` |
| Historial visible | `SharedPreferences` |
| Avance | `DatosApp.inspecciones` en memoria |
| Fotos | Rutas de archivos devueltas por `image_picker` |

## Cobertura mínima creada en Fase 0

La suite `test/v1_characterization_test.dart` cubre:

- Formato actual de fecha sin ceros iniciales.
- Representación textual de un hallazgo.
- Cardinalidad y estructura de los catálogos empacados.
- Controles y roles visibles en login.
- Mensaje para credenciales inválidas.
- Lectura del formato JSON actual del historial.
- Cálculo básico actual de avance desde memoria.

Cámara, GPS, red remota y diálogo de impresión se mantienen como smoke tests manuales hasta que existan adaptadores inyectables. Esto evita alterar producción durante la Fase 0.

## Línea base de validación

- `flutter test --no-pub test/v1_characterization_test.dart`: 8 pruebas aprobadas.
- `flutter analyze --no-pub`: 28 observaciones de nivel `info`, sin errores ni advertencias.
- Las 28 observaciones pertenecen al código V1 existente: APIs de formularios y geolocalización obsoletas, 12 llamadas a `print` y usos de `BuildContext` después de operaciones asíncronas.
- La suite de caracterización nueva no introdujo hallazgos del analizador.
