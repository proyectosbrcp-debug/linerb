# Guía de consistencia visual LINERB

## Espaciado

Usar `LinerbSpacing` para nuevos ajustes visuales:

- `xs`: 4 px.
- `sm`: 8 px.
- `md`: 12 px.
- `lg`: 16 px.
- `xl`: 24 px.
- `xxl`: 32 px.

Evitar nuevos números mágicos cuando exista una constante equivalente.

## Botones

- Botón principal: altura mínima `LinerbTouchTarget.primaryButtonHeight`.
- Botón secundario: altura mínima `LinerbTouchTarget.secondaryButtonHeight`.
- Objetivo táctil mínimo: 48 x 48 px.
- Deshabilitar botones durante operaciones críticas para evitar doble ejecución.

## Estados vacíos

Usar `LinerbEmptyState` cuando una sección no tenga datos.

Debe incluir:

- Icono claro.
- Título breve.
- Explicación accionable.
- Acción opcional solo si aporta claridad.

## Estados de carga

Usar `LinerbLoadingState` cuando la pantalla o sección esté esperando datos.

El mensaje debe explicar qué se está cargando sin mostrar detalles técnicos.

## Semáforo

Los estados verde, amarillo y rojo deben incluir:

- Color.
- Icono.
- Texto visible.
- Etiqueta semántica cuando el estado sea operativo.

No depender únicamente del color.

## Texto

- Mantener tildes y español visible correcto.
- Respetar escalado de texto del sistema.
- Evitar alturas fijas que corten texto.
- Evitar mensajes técnicos al usuario final.

## Errores

Los errores visibles deben ser genéricos y accionables. Los detalles técnicos deben registrarse internamente con `AppLogger`.
