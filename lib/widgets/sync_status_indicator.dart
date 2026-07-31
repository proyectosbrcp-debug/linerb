import 'package:flutter/material.dart';

import '../core/di/app_dependencies.dart';
import '../core/theme/ui_constants.dart';
import '../models/sync_status_snapshot.dart';
import '../pages/sync/sync_status_page.dart';
import '../services/automatic_sync_coordinator.dart';

class SyncStatusIndicator extends StatelessWidget {
  final AutomaticSyncCoordinator? coordinator;

  const SyncStatusIndicator({super.key, this.coordinator});

  @override
  Widget build(BuildContext context) {
    final syncCoordinator =
        coordinator ?? AppDependencies.automaticSyncCoordinator;
    return StreamBuilder<SyncStatusSnapshot>(
      stream: syncCoordinator.stream,
      initialData: syncCoordinator.snapshot,
      builder: (context, snapshot) {
        final status = snapshot.data ?? const SyncStatusSnapshot.initial();
        final label = syncStatusLabel(status);
        return Semantics(
          button: true,
          label: 'Estado de sincronización: $label',
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(
                LinerbTouchTarget.min,
                LinerbTouchTarget.min,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SyncStatusPage(coordinator: syncCoordinator),
                ),
              );
            },
            icon: Icon(_iconFor(status), size: 18),
            label: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }
}

String syncStatusLabel(SyncStatusSnapshot snapshot) {
  if (snapshot.isTrulySynchronized) return 'Actualizado';
  return switch (snapshot.phase) {
    SyncPhase.syncing => 'Sincronizando...',
    SyncPhase.waitingForConnectivity => 'Sin conexión',
    SyncPhase.waitingForAuthentication => 'Sesión requerida',
    SyncPhase.permissionDenied =>
      snapshot.pendingCount > 0
          ? '${snapshot.pendingCount} cambios por permisos'
          : 'Permiso insuficiente',
    SyncPhase.conflict => 'Conflicto pendiente',
    SyncPhase.partialSuccess =>
      snapshot.pendingCount > 0
          ? '${snapshot.pendingCount} cambios pendientes'
          : 'Sincronización parcial',
    SyncPhase.transientFailure => 'Error temporal',
    SyncPhase.unavailable => 'Servicio no disponible',
    SyncPhase.pendingChanges => '${snapshot.pendingCount} cambios pendientes',
    SyncPhase.synchronized =>
      snapshot.pendingCount > 0
          ? '${snapshot.pendingCount} cambios pendientes'
          : 'Pendiente de sincronizar',
    SyncPhase.stopped => 'Sincronización detenida',
    SyncPhase.idle =>
      snapshot.pendingCount > 0
          ? '${snapshot.pendingCount} cambios pendientes'
          : 'Pendiente de sincronizar',
  };
}

IconData _iconFor(SyncStatusSnapshot snapshot) {
  if (snapshot.isTrulySynchronized) return Icons.cloud_done;
  return switch (snapshot.phase) {
    SyncPhase.syncing => Icons.sync,
    SyncPhase.waitingForConnectivity => Icons.cloud_off,
    SyncPhase.waitingForAuthentication => Icons.lock,
    SyncPhase.permissionDenied => Icons.no_accounts,
    SyncPhase.conflict => Icons.warning,
    SyncPhase.partialSuccess || SyncPhase.pendingChanges => Icons.cloud_upload,
    SyncPhase.transientFailure || SyncPhase.unavailable => Icons.error_outline,
    SyncPhase.stopped => Icons.pause_circle,
    SyncPhase.idle || SyncPhase.synchronized => Icons.cloud_queue,
  };
}
