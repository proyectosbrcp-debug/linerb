import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../services/datos_app.dart';

class AvancePage extends StatelessWidget {
  final List<String> lineas;

  const AvancePage({super.key, required this.lineas});

  DateTime? ultimaInspeccion(String linea) {
    final registros = DatosApp.inspecciones.where((i) => i.linea == linea).toList();

    if (registros.isEmpty) return null;

    registros.sort((a, b) => b.fecha.compareTo(a.fecha));
    return registros.first.fecha;
  }

  String estadoSemaforo(DateTime? fecha) {
    if (fecha == null) return "🔴 Nunca inspeccionada";

    final dias = DateTime.now().difference(fecha).inDays;

    if (dias <= 15) return "🟢 $dias días";
    if (dias <= 60) return "🟡 $dias días";
    return "🔴 $dias días";
  }

  @override
  Widget build(BuildContext context) {
    final inspeccionadas = lineas.where((l) => ultimaInspeccion(l) != null).length;
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
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: const Text("Avance de Inspección", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text("AVANCE GENERAL", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text("Líneas registradas: $total"),
                    Text("Inspeccionadas: $inspeccionadas"),
                    Text("Pendientes: ${total - inspeccionadas}"),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: avance),
                    const SizedBox(height: 8),
                    Text("${(avance * 100).toStringAsFixed(1)}%"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              "Prioridad de inspección",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: ordenadas.length,
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
                      trailing: Text(estadoSemaforo(fecha)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
