# Roles y permisos

## Roles

- `administrator`: acceso completo a datos estructurados, dashboard y administración futura.
- `supervisor`: consulta general, dashboard, registro de inspecciones y acciones de supervisión.
- `inspector`: registro de inspecciones y acceso operativo limitado.
- `viewer`: solo lectura; no crea, modifica ni elimina inspecciones.

## PermissionService

Las reglas de autorización de dominio se centralizan en `PermissionService`:

- `canCreateInspection`
- `canUpdateInspection`
- `canDeleteInspection`
- `canViewDashboard`
- `canViewAllInspections`
- `canManageUsers`

Los widgets no duplican estas reglas. Cuando una pantalla necesita decidir si una acción está disponible, consulta el servicio.

## Matriz inicial

| Permiso | administrator | supervisor | inspector | viewer |
| --- | --- | --- | --- | --- |
| Crear inspección | Sí | Sí | Sí | No |
| Actualizar inspección | Sí | Sí | No | No |
| Eliminar inspección | Sí | No | No | No |
| Ver dashboard | Sí | Sí | No | Sí |
| Ver todas las inspecciones | Sí | Sí | No | Sí |
| Administrar usuarios | Sí | No | No | No |

## Refuerzo futuro

Sprint 4.4 documenta que no se debe confiar únicamente en campos enviados por el cliente. La asignación de roles debe reforzarse posteriormente mediante perfiles administrados o custom claims emitidos desde un entorno administrativo seguro.
