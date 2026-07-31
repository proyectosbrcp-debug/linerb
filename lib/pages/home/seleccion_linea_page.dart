import 'package:flutter/material.dart';

import '../../controllers/dashboard_controller.dart';
import '../../controllers/selection_line_controller.dart';
import '../../core/di/app_dependencies.dart';
import '../../models/user_profile.dart';
import '../../services/permission_service.dart';
import '../../widgets/sync_status_indicator.dart';
import '../avance/avance_page.dart';
import '../dashboard/dashboard_page.dart';
import '../historial/historial_page.dart';
import '../inspeccion/registro_inspeccion_page.dart';

class SeleccionLineaPage extends StatefulWidget {
  final String usuario;
  final UserProfile? userProfile;
  final PermissionService permissionService;
  final SelectionLineController? selectionLineController;
  final DashboardController? dashboardController;

  const SeleccionLineaPage({
    super.key,
    required this.usuario,
    this.userProfile,
    this.permissionService = const PermissionService(),
    this.selectionLineController,
    this.dashboardController,
  });

  @override
  State<SeleccionLineaPage> createState() => _SeleccionLineaPageState();
}

class _SeleccionLineaPageState extends State<SeleccionLineaPage> {
  late final SelectionLineController selectionLineController;
  Map<String, dynamic> troncalesJson = {};
  List<String> ramalesJson = [];

  Future<void> cargarJson() async {
    final catalogos = await selectionLineController.cargarCatalogos();

    if (!mounted || catalogos == null) return;

    setState(() {
      troncalesJson = catalogos.troncalesJson;
      ramalesJson = catalogos.ramalesJson;
    });
  }

  @override
  void initState() {
    super.initState();
    selectionLineController =
        widget.selectionLineController ??
        AppDependencies.selectionLineController();
    cargarJson();
  }

  String tipoLinea = 'Troncal';
  String? troncalSeleccionada = 'TRONCAL 1';
  String? subtroncalSeleccionada = 'TRONCAL 1';
  String? ramalSeleccionado;

  final List<String> tiposLinea = ['Troncal', 'Ramal'];

  String get seleccionActual {
    if (tipoLinea == 'Troncal') {
      return '$troncalSeleccionada / $subtroncalSeleccionada';
    }
    return ramalSeleccionado ?? 'Seleccione un ramal';
  }

  bool get seleccionValida {
    if (tipoLinea == 'Troncal') {
      return troncalSeleccionada != null && subtroncalSeleccionada != null;
    }
    return ramalSeleccionado != null;
  }

  bool get puedeCrearInspeccion {
    final profile = widget.userProfile;
    if (profile == null) return true;
    return widget.permissionService.canCreateInspection(profile);
  }

  List<String> todasLasLineas() {
    return selectionLineController.todasLasLineas(troncalesJson, ramalesJson);
  }

  @override
  Widget build(BuildContext context) {
    final bool esTroncal = tipoLinea == 'Troncal';
    if (troncalesJson.isEmpty || ramalesJson.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            'Cargando datos...\n'
            'Troncales: ${troncalesJson.length}\n'
            'Ramales: ${ramalesJson.length}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: const Text(
          "Selección de Línea",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [SyncStatusIndicator()],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.route,
                        size: 80,
                        color: Color(0xFF0D47A1),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "Seleccione el tipo de línea a inspeccionar",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 25),
                      DropdownButtonFormField<String>(
                        initialValue: tipoLinea,
                        decoration: const InputDecoration(
                          labelText: "Tipo de línea",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.merge_type),
                        ),
                        items: tiposLinea.map((item) {
                          return DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: (valor) {
                          setState(() {
                            tipoLinea = valor!;
                            if (tipoLinea == 'Troncal') {
                              troncalSeleccionada = troncalesJson.keys.first;
                              subtroncalSeleccionada =
                                  troncalesJson[troncalSeleccionada]!.first;
                              ramalSeleccionado = null;
                            } else {
                              troncalSeleccionada = null;
                              subtroncalSeleccionada = null;
                              ramalSeleccionado = ramalesJson.first;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                      if (esTroncal) ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey('troncal-$troncalSeleccionada'),
                          initialValue: troncalSeleccionada,
                          decoration: const InputDecoration(
                            labelText: "Troncal",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.alt_route),
                          ),
                          items: troncalesJson.keys.map((item) {
                            return DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            );
                          }).toList(),
                          onChanged: (valor) {
                            setState(() {
                              troncalSeleccionada = valor!;
                              subtroncalSeleccionada = List<String>.from(
                                troncalesJson[troncalSeleccionada] ?? [],
                              ).first;
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'subtroncal-$troncalSeleccionada-$subtroncalSeleccionada',
                          ),
                          initialValue: subtroncalSeleccionada,
                          decoration: const InputDecoration(
                            labelText: "Subtroncal",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.account_tree),
                          ),
                          items:
                              List<String>.from(
                                troncalesJson[troncalSeleccionada] ?? [],
                              ).map((item) {
                                return DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                );
                              }).toList(),
                          onChanged: (valor) {
                            setState(() {
                              subtroncalSeleccionada = valor!;
                            });
                          },
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey('ramal-$ramalSeleccionado'),
                          initialValue: ramalSeleccionado,
                          decoration: const InputDecoration(
                            labelText: "Ramal",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.account_tree),
                          ),
                          items: ramalesJson.map((item) {
                            return DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            );
                          }).toList(),
                          onChanged: (valor) {
                            setState(() {
                              ramalSeleccionado = valor!;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 25),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.info),
                          title: const Text("Selección actual"),
                          subtitle: Text(seleccionActual),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: seleccionValida && puedeCrearInspeccion
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RegistroInspeccionPage(
                                          usuario: widget.usuario,
                                          tipoLinea: tipoLinea,
                                          seleccionLinea: seleccionActual,
                                        ),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("INICIAR INSPECCIÓN"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistorialPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: const Text("HISTORIAL"),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AvancePage(lineas: todasLasLineas()),
                            ),
                          );
                        },
                        icon: const Icon(Icons.analytics),
                        label: const Text("AVANCE"),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DashboardPage(
                                controller: widget.dashboardController,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.dashboard),
                        label: const Text("DASHBOARD"),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
