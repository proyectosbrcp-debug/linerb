# Sprint 4.6 - Presentación del informe PDF

## Alcance

Sprint 4.6 modifica únicamente la generación local del informe PDF y el
servicio necesario para construir la página final de mapa de hallazgos.

No se modifican sincronización, SQLite, Firestore, autenticación, permisos,
dashboard, navegación, flujo de captura, modelo de inspección, lógica de
hallazgos, almacenamiento local de fotografías ni reglas Firebase.

## Generador actualizado

El punto de entrada visible continúa siendo `ResumenInspeccionPage.generarPdf`.
La construcción del documento se extrajo a `InspectionPdfService` para separar
responsabilidades y permitir pruebas sin crear un segundo generador paralelo.

Responsabilidades actuales:

- `ResumenInspeccionPage`: mantiene la pantalla y llama a `Printing.layoutPdf`.
- `InspectionPdfService`: arma bytes del PDF local.
- `PdfFontProvider`: carga la fuente Unicode local y construye el tema PDF.
- `FindingsMapImageProvider`: entrega la imagen del mapa o un fallo tipado.
- `LocalPhotoService`: sigue resolviendo rutas locales de las 2 fotografías.

## Fuente Unicode

El PDF usa Roboto Regular y Roboto Bold como assets locales:

- `assets/fonts/Roboto-Regular.ttf`
- `assets/fonts/Roboto-Bold.ttf`

Procedencia:

- artefactos `material_fonts` del SDK Flutter instalado localmente.

Licencia:

- Roboto está distribuida por Google bajo Apache License 2.0.

Estrategia:

- las fuentes se cargan mediante `PdfFontProvider`;
- se construye `pw.ThemeData.withFont(base: regular, bold: bold)`;
- el mismo tema se aplica a todas las páginas `pw.MultiPage`;
- la carga queda cacheada en un `Future<PdfFontBundle>` para evitar cargas
  repetidas o carreras si dos generaciones solicitan el tema al mismo tiempo;
- no se usan rutas absolutas del sistema en tiempo de ejecución;
- no se descargan fuentes en tiempo de ejecución.

## Títulos principales

Los títulos principales del PDF son:

- `INFORMACIÓN GENERAL`
- `HALLAZGOS OPERATIVOS`
- `MAPA DE UBICACIÓN DE HALLAZGOS`

No tienen prefijo numérico, se mantienen en mayúscula y conservan el estilo de
fondo verde con texto blanco.

## Información general

Los subtítulos se renderizan con etiqueta en negrilla y valor normal:

- Fecha:
- Responsable:
- Usuario:
- Tipo de línea:
- Línea:
- Punto de referencia:
- Estado operativo:
- Total hallazgos:

Se corrigen las grafías esperadas para `Estado operativo`, `Tipo de línea` e
`Información`.

## Hallazgos operativos

Cada hallazgo se numera desde 1 y la numeración no depende de la página.

Formato:

```text
1. VÁLVULAS - No operativa
```

Reglas:

- número primero;
- categoría en mayúscula;
- número y categoría en negrilla;
- estado conservado después del guion;
- categoría real del hallazgo, sin forzar todos a válvulas.

Campos internos:

- Latitud:
- Longitud:
- Descripción:

Solo las etiquetas van en negrilla; los valores quedan normales.

## Fotografías

Cada inspección conserva exactamente 2 fotografías como máximo, resueltas desde
rutas locales existentes. El PDF usa esas imágenes solo en memoria durante la
generación local del documento.

No se sincronizan fotografías, PDF, rutas locales ni mapa.

## Pie de página

El PDF reserva una zona inferior segura de 96 puntos para barras decorativas,
numeración y margen. La tubería decorativa queda como fondo de menor prioridad y
con opacidad reducida; el contenido del hallazgo y sus fotografías tienen
prioridad visual.
