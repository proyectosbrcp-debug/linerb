# Reporte de validación Sprint 4.6

## Estado del cierre

SPRINT 4.6 NO CERRADO

Causa exacta:

- se corrigió la causa técnica del mojibake incorporando una fuente Unicode
  embebida en el PDF;
- la validación estática de los archivos modificados no tiene issues;
- se agregó la prueba mínima solicitada para cargar Roboto Regular/Bold y guardar
  un PDF Unicode mínimo;
- el runner `flutter test` sigue colgado sin salida incluso al ejecutar esa
  prueba mínima por `--plain-name`;
- falta completar la revalidación obligatoria con Flutter y regenerar los PDFs
  para revisión visual final.

## Causa raíz definitiva

El mojibake visual no provenía de los modelos, de JSON ni de conversiones
manuales de texto. El diagnóstico confirmó:

- las cadenas principales de `InspectionPdfService` están en UTF-8 correcto;
- la revisión previa fallaba al renderizar caracteres españoles porque
  `package:pdf` estaba usando Helvetica/Helvetica-Bold;
- Helvetica no tiene soporte Unicode suficiente para los textos requeridos en
  español;
- documentos Sprint 4.6 anteriores contenían texto dañado y fueron normalizados
  a UTF-8 correcto.

## Fuente Unicode seleccionada

Fuente:

- Roboto Regular;
- Roboto Bold.

Assets agregados:

```text
D:\APP\LINERB\linerb\assets\fonts\Roboto-Regular.ttf
D:\APP\LINERB\linerb\assets\fonts\Roboto-Bold.ttf
```

Procedencia:

- artefactos `material_fonts` del SDK Flutter instalado localmente.

Licencia:

- Roboto está distribuida por Google bajo Apache License 2.0.

Estrategia de carga:

- `PdfFontProvider` carga las fuentes desde assets declarados;
- construye un `pw.ThemeData.withFont(base: regular, bold: bold)`;
- `InspectionPdfService` aplica el mismo tema a todas las páginas del informe;
- las fuentes se cachean con `Future<PdfFontBundle>` dentro del proveedor para
  evitar recargar bytes por cada PDF y para compartir una carga concurrente;
- si la carga falla, el future cacheado se limpia y el error se propaga;
- no se usan fuentes del sistema mediante rutas absolutas de Windows;
- no se descargan fuentes en tiempo de ejecución.

## Validación ejecutada en esta sesión

### `flutter analyze`

Comando ejecutado antes del bloqueo posterior del SDK:

```bash
flutter analyze
```

Resultado exacto:

```text
Analyzing linerb...
No issues found! (ran in 17.2s)
```

### Análisis estático directo de archivos modificados

Comando ejecutado:

```bash
D:\APP\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib/services/pdf_font_provider.dart lib/services/inspection_pdf_service.dart test/pdf_sprint_4_6_test.dart
```

Resultado exacto:

```text
Analyzing pdf_font_provider.dart, inspection_pdf_service.dart, pdf_sprint_4_6_test.dart...
No issues found!
```

Análisis completo posterior:

```bash
D:\APP\flutter\bin\cache\dart-sdk\bin\dart.exe analyze .
```

Resultado exacto:

```text
Analyzing ....
No issues found!
```

## Diagnóstico del bloqueo de pruebas PDF

Hipótesis descartadas por prueba acotada:

- `document.save()` del informe completo;
- proveedor de mapa fake;
- HTTP real;
- escritura de múltiples artefactos;
- carga de fotografías;
- generación de varios PDFs en una sola prueba.

Evidencia:

- el comando se cuelga incluso con una prueba por nombre que solo compara rutas
  de `PdfFontProvider`;
- también se cuelga con la nueva prueba mínima
  `carga fuentes Unicode y genera PDF mínimo`;
- no se recibe salida del runner antes del timeout;
- tras cada timeout queda un proceso `dart` activo asociado al tooling.

Último punto alcanzado antes del bloqueo:

- el proceso `flutter test` arranca, pero no llega a emitir eventos de prueba en
  stdout antes del timeout.

Conclusión:

- el bloqueo observado en esta sesión corresponde al runner/tooling Flutter y no
  a una espera interna confirmada de `PdfFontProvider`, mapa, fotos o guardado
  del PDF.

### `flutter test test/pdf_sprint_4_6_test.dart`

Intento ejecutado:

```bash
flutter test test/pdf_sprint_4_6_test.dart --reporter expanded
```

Resultado en esta sesión:

```text
command timed out after 300736 milliseconds
```

Segundo intento acotado:

```bash
flutter test test/pdf_sprint_4_6_test.dart --plain-name "textos fuente" --no-pub --reporter expanded
```

Resultado:

```text
command timed out after 180971 milliseconds
```

No se obtuvo salida de pruebas desde este entorno después del cambio de fuentes.

### Prueba mínima Unicode

Prueba agregada:

```text
carga fuentes Unicode y genera PDF mínimo
```

Contenido cubierto:

- inicialización de `TestWidgetsFlutterBinding`;
- carga de Roboto Regular;
- carga de Roboto Bold;
- construcción de `pw.ThemeData`;
- creación de `pw.Document`;
- texto con `INFORMACIÓN`, `UBICACIÓN`, `VÁLVULAS`, `DESCRIPCIÓN`, `LÍNEA`,
  `NIÑO`, `CAÑERÍA` y `OPERACIÓN`;
- `document.save()`.

Comando ejecutado:

```bash
flutter test test/pdf_sprint_4_6_test.dart --plain-name "carga fuentes Unicode y genera PDF mínimo" --reporter expanded
```

Resultado en esta sesión:

```text
command timed out after 120548 milliseconds
```

### `flutter test test/findings_map_service_test.dart`

Pendiente de re-ejecución después de liberar el lockfile del SDK Flutter.

### `flutter test`

Pendiente de re-ejecución después de liberar el lockfile del SDK Flutter.

Cantidad total identificada de pruebas en `test/` antes de este ajuste:

- 177 pruebas.

El total aumentará por las pruebas Unicode agregadas en
`test/pdf_sprint_4_6_test.dart`.

### `flutter build apk --debug`

Pendiente de re-ejecución después de liberar el lockfile del SDK Flutter.

Último APK observado antes de este ajuste:

```text
D:\APP\LINERB\linerb\build\app\outputs\flutter-apk\app-debug.apk
```

### `git diff --check`

Pendiente de re-ejecución final.

## PDFs de validación

Ruta esperada para regeneración:

```text
D:\APP\LINERB\linerb\build\sprint_4_6_pdf_validation
```

Archivos esperados:

```text
D:\APP\LINERB\linerb\build\sprint_4_6_pdf_validation\informe_corto.pdf
D:\APP\LINERB\linerb\build\sprint_4_6_pdf_validation\informe_medio.pdf
D:\APP\LINERB\linerb\build\sprint_4_6_pdf_validation\informe_15_hallazgos.pdf
D:\APP\LINERB\linerb\build\sprint_4_6_pdf_validation\informe_dos_fotos_por_hallazgo.pdf
D:\APP\LINERB\linerb\build\sprint_4_6_pdf_validation\informe_con_mapa.pdf
D:\APP\LINERB\linerb\build\sprint_4_6_pdf_validation\informe_sin_mapa_disponible.pdf
```

Los PDFs deben regenerarse después del cambio de fuente para confirmar que ya no
hay mojibake ni advertencias Helvetica.

Estado en esta sesión:

- no se regeneraron PDFs nuevos después de agregar Roboto porque
  `flutter test test/pdf_sprint_4_6_test.dart` quedó colgado;
- los PDFs existentes en la carpeta corresponden a la generación anterior y no
  sirven para cerrar visualmente la corrección Unicode.

## Revisión visual pendiente

Se debe renderizar nuevamente con Poppler después de regenerar PDFs y revisar:

- `INFORMACIÓN GENERAL`;
- `HALLAZGOS OPERATIVOS`;
- `MAPA DE UBICACIÓN DE HALLAZGOS`;
- `VÁLVULAS`;
- `VEGETACIÓN`;
- `SOPORTERÍA`;
- `Descripción`;
- leyenda del mapa;
- fallback del mapa;
- rosa de los vientos con `O` de oeste.

Criterio de aceptación visual:

- no deben aparecer secuencias de doble codificación;
- no deben aparecer caracteres de reemplazo;
- no deben aparecer cuadros vacíos;
- no deben faltar tildes, diéresis ni ñ.

## Estado de advertencias Helvetica

Estado esperado después del cambio:

- no deben aparecer `Helvetica has no Unicode support`;
- no deben aparecer `Helvetica-Bold has no Unicode support`.

Validación pendiente:

- confirmar durante `flutter test test/pdf_sprint_4_6_test.dart`;
- confirmar durante regeneración/render visual de PDFs.

## Confirmaciones de alcance

- No se modificó sincronización.
- No se modificó SQLite.
- No se modificó Firestore.
- No se modificó autenticación.
- No se agregó Firebase Storage.
- Las fotografías siguen únicamente en el dispositivo.
- El PDF sigue siendo local.
- El mapa se usa únicamente dentro del PDF local.
- El mapa no se sincroniza.
- Las rutas locales no se sincronizan.
