# Checklist de accesibilidad LINERB

## Táctil

- [x] Objetivos críticos con al menos 48 x 48 px.
- [x] Botones principales con altura mínima consistente.
- [x] Controles de sincronización con área táctil suficiente.
- [ ] Validar con guantes en dispositivo físico.

## Texto y escalado

- [x] Estados vacíos soportan texto escalado y scroll.
- [x] Avance soporta teléfono pequeño y text scaling 2.0.
- [x] No se desactiva el escalado de texto del sistema.
- [ ] Revisar manualmente todas las pantallas heredadas a escala 2.0.

## Semántica

- [x] Progreso general de Avance tiene etiqueta semántica.
- [x] Semáforo de Avance tiene texto, icono y etiqueta semántica.
- [x] Mensajes de login usan región viva.
- [x] Estado de sincronización usa etiqueta semántica.

## Color y contraste

- [x] Semáforo no depende únicamente del color.
- [x] Se mantiene paleta actual de LINERB.
- [ ] Medición formal de contraste en dispositivo real pendiente.

## Mensajes

- [x] Login evita detalles técnicos en errores.
- [x] Sincronización mantiene mensajes amigables.
- [x] Estados vacíos incluyen explicación breve.

## Tamaños verificados por prueba

- 320 x 568 con text scaling 2.0.

## Pendientes manuales

- 360 x 640.
- 412 x 915.
- Tablet pequeña.
- Teclado abierto en formulario de registro.
- Revisión con brillo alto en campo.
