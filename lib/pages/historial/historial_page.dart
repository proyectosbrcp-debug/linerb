import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/date_utils.dart';
import '../../models/inspeccion.dart';

class HistorialPage extends StatefulWidget {
  const HistorialPage({super.key});

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  List<Inspeccion> inspecciones = [];

  @override
  void initState() {
    super.initState();
    cargarHistorial();
  }

  Future<void> cargarHistorial() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    final historialGuardado =
        prefs.getStringList('historial_inspecciones') ?? [];

    final datos = historialGuardado.map((registro) {
      final data = jsonDecode(registro);

      return Inspeccion(
        linea: data['linea'],
        tipoLinea: data['tipoLinea'],
        responsable: data['responsable'],
        fecha: DateTime.parse(data['fecha']),
        estadoLinea: data['estadoLinea'],
        puntoReferencia: data['puntoReferencia'],
        observaciones: data['observaciones'],
      );
    }).toList();

    setState(() {
      inspecciones = datos;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: const Text(
          "Historial de Líneas",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "HISTORIAL DE LÍNEAS INSPECCIONADAS",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: inspecciones.isEmpty
                  ? const Center(
                      child: Text("Aún no hay inspecciones registradas"),
                    )
                  : ListView.builder(
                      itemCount: inspecciones.length,
                      itemBuilder: (context, index) {
                        final item = inspecciones[index];

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.check_circle),
                            title: Text(item.linea),
                            subtitle: Text(
                              "Fecha: ${fechaCorta(item.fecha)}\nResponsable: ${item.responsable}",
                            ),
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

