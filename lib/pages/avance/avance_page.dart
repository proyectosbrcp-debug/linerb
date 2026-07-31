import 'package:flutter/material.dart';

import '../../controllers/progress_controller.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/theme/ui_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../widgets/linerb_empty_state.dart';

class AvancePage extends StatelessWidget {
  final List<String> lineas;
  final ProgressController? progressController;

  const AvancePage({super.key, required this.lineas, this.progressController});

  DateTime? ultimaInspeccion(String linea) {
    return (progressController ?? AppDependencies.progressController)
        .ultimaInspeccion(linea);
  }

  String estadoSemaforo(DateTime? fecha) {
    return (progressController ?? AppDependencies.progressController)
        .estadoSemaforo(fecha);
  }

  @override
  Widget build(BuildContext context) {
    final inspeccionadas = lineas
        .where((l) => ultimaInspeccion(l) != null)
        .length;
    final total = lineas.length;
    final avance = total == 0 ? 0.0 : inspeccionadas / total;

    final ordenadas = [...lineas];

    ordenadas.sort((a, b) {
      final fa = ultimaInspeccion(a);
      final fb = ultimaInspeccion(b);

      if (fa == null && fb == null) return 0;
      if (fa == null) return -1;
      if (fb == null) return 1;

      return fa.compareTo(fb);
    });

    return Scaffold(
      backgroundColor: LinerbColors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: LinerbColors.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text(
          "Avance de Inspección",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Text(
                        "AVANCE GENERAL",
                        style: LinerbTextStyles.sectionTitle,
                      ),
                      const SizedBox(height: LinerbSpacing.md),
                      Text("Líneas registradas: $total"),
                      Text("Inspeccionadas: $inspeccionadas"),
                      Text("Pendientes: ${total - inspeccionadas}"),
                      const SizedBox(height: LinerbSpacing.md),
                      Semantics(
                        container: true,
                        label:
                            'Avance general ${(avance * 100).toStringAsFixed(1)} por ciento',
                        child: ExcludeSemantics(
                          child: LinearProgressIndicator(value: avance),
                        ),
                      ),
                      const SizedBox(height: LinerbSpacing.sm),
                      Text("${(avance * 100).toStringAsFixed(1)}%"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: LinerbSpacing.lg),
              const Text(
                "Prioridad de inspección",
                style: LinerbTextStyles.sectionTitle,
              ),
              const SizedBox(height: LinerbSpacing.md),
              if (ordenadas.isEmpty)
                const SizedBox(
                  height: 260,
                  child: LinerbEmptyState(
                    icon: Icons.analytics_outlined,
                    title: 'Sin líneas para mostrar',
                    message:
                        'Cuando el catálogo esté disponible se mostrará el avance por línea.',
                  ),
                )
              else
                ListView.builder(
                  itemCount: ordenadas.length,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final linea = ordenadas[index];
                    final fecha = ultimaInspeccion(linea);

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.flag),
                        title: Text(linea),
                        subtitle: Text(
                          fecha == null
                              ? "Última inspección: Nunca"
                              : "Última inspección: ${fechaCorta(fecha)}",
                        ),
                        trailing: _SemaforoStatusLabel(
                          label: estadoSemaforo(fecha),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SemaforoStatusLabel extends StatelessWidget {
  final String label;

  const _SemaforoStatusLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(label);
    final semanticLabel = _semanticLabelFor(label);
    return Semantics(
      label: semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(label), color: color, size: 18),
          const SizedBox(width: LinerbSpacing.xs),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(String value) {
    if (value.contains('🟢') || value.contains('Verde')) {
      return LinerbColors.success;
    }
    if (value.contains('🟡') || value.contains('Amarillo')) {
      return LinerbColors.warningText;
    }
    return LinerbColors.danger;
  }

  IconData _iconFor(String value) {
    if (value.contains('🟢') || value.contains('Verde')) {
      return Icons.check_circle;
    }
    if (value.contains('🟡') || value.contains('Amarillo')) {
      return Icons.warning_amber;
    }
    return Icons.error;
  }

  String _semanticLabelFor(String value) {
    if (value.contains('🟢') || value.contains('Verde')) {
      return 'Estado vigente: $value';
    }
    if (value.contains('🟡') || value.contains('Amarillo')) {
      return 'Estado próximo a vencer: $value';
    }
    return 'Estado vencido o nunca inspeccionado: $value';
  }
}
