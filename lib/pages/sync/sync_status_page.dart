import 'package:flutter/material.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/theme/ui_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../models/sync_status_snapshot.dart';
import '../../models/user_profile.dart';
import '../../services/automatic_sync_coordinator.dart';
import '../../services/sync_error_classifier.dart';
import '../../widgets/sync_status_indicator.dart';

class SyncStatusPage extends StatelessWidget {
  final AutomaticSyncCoordinator? coordinator;
  final SyncErrorClassifier errorClassifier;

  const SyncStatusPage({
    super.key,
    this.coordinator,
    this.errorClassifier = const SyncErrorClassifier(),
  });

  @override
  Widget build(BuildContext context) {
    final syncCoordinator =
        coordinator ?? AppDependencies.automaticSyncCoordinator;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: const Text('Sincronización'),
      ),
      body: StreamBuilder<SyncStatusSnapshot>(
        stream: syncCoordinator.stream,
        initialData: syncCoordinator.snapshot,
        builder: (context, snapshot) {
          final status = snapshot.data ?? const SyncStatusSnapshot.initial();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_sync),
                  title: Semantics(
                    liveRegion: true,
                    child: Text(syncStatusLabel(status)),
                  ),
                  subtitle: Text(_friendlyStatusText(status)),
                ),
              ),
              const SizedBox(height: 10),
              _DetailCard(
                rows: [
                  _DetailRow(
                    'Última sincronización exitosa',
                    _date(status.lastSuccessfulSyncAt),
                  ),
                  _DetailRow('Último intento', _date(status.lastAttemptAt)),
                  _DetailRow('Pendientes', '${status.pendingCount}'),
                  _DetailRow('Fallidos', '${status.failedCount}'),
                  _DetailRow('Conflictos', '${status.conflictCount}'),
                  _DetailRow(
                    'Requieren atención',
                    '${status.requiresAttentionCount}',
                  ),
                  _DetailRow(
                    'Enviados último ciclo',
                    '${status.uploadedCount}',
                  ),
                  _DetailRow(
                    'Descargados último ciclo',
                    '${status.downloadedCount}',
                  ),
                  _DetailRow(
                    'Aplicados último ciclo',
                    '${status.appliedCount}',
                  ),
                  _DetailRow(
                    'Próximo reintento',
                    _date(status.retryScheduledAt),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _DetailCard(
                rows: [
                  _DetailRow(
                    'Conectividad',
                    status.connectivityAvailable
                        ? 'Disponible'
                        : 'Sin conexión',
                  ),
                  _DetailRow(
                    'Sesión',
                    status.authenticated ? 'Activa' : 'Requerida',
                  ),
                  _DetailRow(
                    'Perfil',
                    status.profileActive ? 'Activo' : 'No activo',
                  ),
                  _DetailRow('Rol', _role(status.role)),
                  _DetailRow(
                    'Permiso de envío',
                    status.canPush ? 'Disponible' : 'No disponible',
                  ),
                  _DetailRow(
                    'Permiso de descarga',
                    status.canPull ? 'Disponible' : 'No disponible',
                  ),
                  _DetailRow(
                    'Modo local',
                    status.diagnostics.degraded ? 'Degradado' : 'Listo',
                  ),
                ],
              ),
              if (status.lastErrorCategory != null) ...[
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      errorClassifier.friendlyMessage(
                        status.lastErrorCategory!,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed:
                    status.authenticated &&
                        status.profileActive &&
                        status.canPull &&
                        status.phase != SyncPhase.syncing
                    ? () {
                        syncCoordinator.syncNow(trigger: SyncTrigger.manual);
                      }
                    : null,
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar ahora'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    LinerbTouchTarget.primaryButtonHeight,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _friendlyStatusText(SyncStatusSnapshot status) {
    if (!status.connectivityAvailable) {
      return 'Los datos permanecen guardados en este dispositivo.';
    }
    if (!status.authenticated) return 'Inicia sesión para sincronizar.';
    if (status.pendingCount > 0 && !status.canPush) {
      return 'Hay cambios pendientes que este rol no puede enviar.';
    }
    if (status.pendingCount > 0) {
      return 'Se sincronizarán cuando existan condiciones adecuadas.';
    }
    return 'SQLite sigue siendo la fuente local de trabajo.';
  }

  String _date(DateTime? value) {
    if (value == null) return 'No disponible';
    return '${fechaCorta(value)} ${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _role(UserRole? role) {
    return switch (role) {
      UserRole.administrator => 'Administrador',
      UserRole.supervisor => 'Supervisor',
      UserRole.inspector => 'Inspector',
      UserRole.viewer => 'Viewer',
      null => 'No disponible',
    };
  }
}

class _DetailCard extends StatelessWidget {
  final List<_DetailRow> rows;

  const _DetailCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(row.value, textAlign: TextAlign.right),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);
}
