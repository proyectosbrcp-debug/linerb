# Mapa estático de hallazgos

## Servicio

`FindingsMapService` y `GoogleStaticFindingsMapImageProvider` preparan la página
final del mapa del PDF.

El proveedor usa Google Maps Static API mediante HTTPS y `http`, dependencia ya
existente en el proyecto. No se agregó Google Maps SDK, WebView, scraping ni
Firebase Storage.

## API key

La clave se lee por `dart-define`:

```bash
--dart-define=GOOGLE_MAPS_STATIC_API_KEY=...
```

La clave no se guarda en el repositorio, no se documenta con valores reales y no
se registra con `AppLogger`.

## Datos enviados

La solicitud al servicio de mapas contiene únicamente:

- coordenadas;
- tipo de mapa;
- tamaño;
- escala;
- centro;
- zoom;
- marcadores;
- clave técnica.

Nunca se envían responsable, usuario, descripciones, fotografías, PDF, contrato,
borrador ni rutas locales.

## Coordenadas válidas

Una coordenada se considera válida si:

- latitud está entre -90 y 90;
- longitud está entre -180 y 180;
- ambos valores son numéricos;
- no son `NaN`;
- no son infinitos;
- el campo fuente no está vacío.

Los hallazgos sin coordenadas siguen apareciendo en el informe y en la leyenda
como `Sin coordenadas`, pero no generan marcador.

## Encuadre

El encuadre calcula:

- latitud mínima y máxima;
- longitud mínima y máxima;
- centro geográfico aproximado;
- padding geográfico;
- zoom acotado entre 3 y 18.

El mapa usa tamaño vertical `640x900` para aprovechar la hoja y mantener norte
arriba. No hay rotación, inclinación ni perspectiva 3D.

## Marcadores

Los marcadores son rojos y respetan el orden de numeración del informe.

Google Maps Static API limita la etiqueta del marcador a un carácter. Por eso:

- hallazgos 1 a 9 usan etiqueta numérica;
- hallazgos 10 en adelante conservan marcador rojo sin etiqueta;
- ningún punto válido se omite;
- la leyenda conserva la correspondencia completa.

## Fallos

Si no hay conectividad, hay timeout, clave inválida, cuota agotada, error HTTP o
respuesta no imagen, el PDF se genera de todas formas y muestra:

```text
Mapa no disponible. Las coordenadas de los hallazgos se incluyen en la leyenda.
```

La imagen del mapa se usa temporalmente en memoria durante la generación del PDF
local. No se guarda en Firestore, SQLite ni Storage, y no se sincroniza.

## Rosa de los vientos

La rosa de los vientos se dibuja como vector PDF local/offline. Muestra N, S, E
y O, con norte hacia arriba.
