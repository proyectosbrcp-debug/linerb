# Estrategia de paginación del PDF

## Objetivo

Evitar que las fotografías queden aisladas de su hallazgo y proteger el pie de
página en todas las páginas del informe.

## Restricción técnica

`package:pdf` 3.12.0 no expone `pw.KeepTogether`. Por compatibilidad se usa una
estrategia con:

- `pw.MultiPage`;
- `pw.NewPage(freeSpace: ...)`;
- bloques de hallazgo no particionables moderados;
- margen inferior reservado.

## Bloque visual de hallazgo

Cada bloque contiene:

1. título numerado;
2. latitud;
3. longitud;
4. descripción;
5. fotografía 1, si existe;
6. fotografía 2, si existe.

Antes de insertar cada bloque se estima su altura. Si el espacio libre de la
página es insuficiente, `pw.NewPage(freeSpace: estimado)` mueve el bloque a la
siguiente página.

## Bloques grandes

Si un bloque es demasiado grande para una sola página, se permite partición
controlada solo como último recurso del motor PDF. La estimación mantiene título,
coordenadas, descripción y fotografías inmediatamente relacionadas, evitando
fotos sin identificación visual.

## Zona segura inferior

La página usa margen inferior de 96 puntos. Ningún contenido se compone dentro
de esa reserva. El pie de página incluye la numeración `Página X de Y` y se
renderiza en todas las páginas, incluida la página de mapa.

## Prioridad de capas

Prioridad visual:

1. contenido del hallazgo;
2. fotografías;
3. pie de página;
4. tubería decorativa.

La tubería decorativa queda como fondo con opacidad reducida y no se usa para
forzar saltos de página.
