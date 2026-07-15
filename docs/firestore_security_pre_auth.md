# Firestore Security Rules pre-autenticación

## Estado Sprint 4.2

No se agrega autenticación en este sprint.

Por seguridad, las reglas iniciales deniegan lectura y escritura pública.

Archivo:

```text
firestore.rules
```

Regla:

```text
allow read, write: if false;
```

## Pruebas

Las pruebas automatizadas no dependen de una base productiva.

La configuración de emulador queda declarada en `firebase.json` para pruebas controladas futuras.

## Sprint futuro

Sprint 4.3 deberá incorporar autenticación real y reglas basadas en usuario/rol.

No se deben publicar reglas abiertas como:

```text
allow read, write: if true;
```
