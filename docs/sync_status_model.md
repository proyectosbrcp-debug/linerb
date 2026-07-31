# Modelo de estado de sincronización

Modelo central: `SyncStatusSnapshot`.

Campos principales:

- `phase`
- `startedAt`
- `finishedAt`
- `lastSuccessfulSyncAt`
- `lastAttemptAt`
- `uploadedCount`
- `downloadedCount`
- `appliedCount`
- `failedCount`
- `pendingCount`
- `conflictCount`
- `requiresAttentionCount`
- `retryScheduledAt`
- `connectivityAvailable`
- `authenticated`
- `profileActive`
- `canPush`
- `canPull`
- `lastErrorCategory`
- `lastErrorAt`
- `duration`
- `trigger`
- `role`
- `diagnostics`

Fases tipadas:

- `idle`
- `waitingForConnectivity`
- `waitingForAuthentication`
- `syncing`
- `synchronized`
- `pendingChanges`
- `partialSuccess`
- `transientFailure`
- `permissionDenied`
- `conflict`
- `unavailable`
- `stopped`

Disparadores tipados:

- `appStart`
- `inspectionFinalized`
- `connectivityRecovered`
- `periodic`
- `manual`
- `authSessionRestored`
- `retry`

## Definición de "Actualizado"

La app solo puede mostrar "Actualizado" si:

- la fase es `synchronized`;
- `pendingCount == 0`;
- `failedCount == 0`;
- `conflictCount == 0`;
- el usuario está autenticado;
- el perfil está activo;
- `lastSuccessfulSyncAt` existe.

Si existe cola pendiente o errores activos, se muestra estado pendiente, parcial, conflicto o permiso insuficiente.
