# Seguridad Firestore autenticada

## Colección de perfiles

Ruta:

```text
users/{uid}
```

Campos permitidos:

- `uid`
- `display_name`
- `email`
- `role`
- `active`
- `created_at`
- `updated_at`

No se guardan contraseñas, tokens, fotografías, rutas locales, PDF, borrador ni identificadores sensibles de dispositivo.

## Reglas aplicadas

`firestore.rules` ahora:

- deniega todo acceso no autenticado;
- exige perfil activo;
- permite a usuarios activos leer su propio perfil;
- reserva administración de perfiles a `administrator`;
- impide que un administrator cambie su propio rol;
- permite lectura de inspecciones y hallazgos a usuarios activos;
- permite creación de datos estructurados a administrator, supervisor e inspector;
- reserva actualización a administrator y supervisor;
- reserva eliminación a administrator y supervisor;
- valida campos permitidos en `users`, `inspections` y `findings`;
- mantiene denegación por defecto para cualquier otra ruta.

## Exclusiones explícitas

Fotografías, rutas locales, PDF y borrador no forman parte del esquema remoto ni de las reglas porque siguen siendo exclusivamente locales.

## Validación con emulador

Las reglas deben validarse con Firebase Emulator cuando esté disponible en el entorno local/CI. No se usan usuarios productivos en pruebas automatizadas.
