import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/catalog_urls.dart';
import '../avance/avance_page.dart';
import '../historial/historial_page.dart';
import '../inspeccion/registro_inspeccion_page.dart';

class SeleccionLineaPage extends StatefulWidget {
  final String usuario;

  const SeleccionLineaPage({super.key, required this.usuario});

  @override
  State<SeleccionLineaPage> createState() => _SeleccionLineaPageState();
}

class _SeleccionLineaPageState extends State<SeleccionLineaPage> {
  Map<String, dynamic> troncalesJson = {};
List<String> ramalesJson = [];
Future<void> cargarJson() async {
  final prefs = await SharedPreferences.getInstance();

  try {
    print("========== CONSULTANDO FIREBASE ==========");

    final troncalesResponse = await http.get(
      Uri.parse(troncalesCatalogUrl),
    );

    final ramalesResponse = await http.get(
      Uri.parse(ramalesCatalogUrl),
    );

    if (troncalesResponse.statusCode == 200 &&
        ramalesResponse.statusCode == 200) {
      await prefs.setString('json_troncales_cache', troncalesResponse.body);
      await prefs.setString('json_ramales_cache', ramalesResponse.body);

      if (!mounted) return;

      setState(() {
        troncalesJson = json.decode(troncalesResponse.body);
        ramalesJson = List<String>.from(
          json.decode(ramalesResponse.body)['ramales'],
        );
      });

      print("✅ JSON FIREBASE CARGADO Y GUARDADO EN CACHE");
      return;
    }
  } catch (e) {
    print("⚠ No se pudo cargar desde Firebase");
    print(e);
  }

  try {
    print("========== CARGANDO CACHE LOCAL ==========");

    final troncalesCache = prefs.getString('json_troncales_cache');
    final ramalesCache = prefs.getString('json_ramales_cache');

    if (troncalesCache != null && ramalesCache != null) {
      if (!mounted) return;

      setState(() {
        troncalesJson = json.decode(troncalesCache);
        ramalesJson = List<String>.from(
          json.decode(ramalesCache)['ramales'],
        );
      });

      print("✅ JSON CARGADO DESDE CACHE LOCAL");
      return;
    }
  } catch (e) {
    print("⚠ No se pudo cargar cache local");
    print(e);
  }

  try {
    print("========== CARGANDO JSON INTERNO ==========");

    final String troncalesData =
        await rootBundle.loadString('assets/data/troncales.json');

    final String ramalesData =
        await rootBundle.loadString('assets/data/ramales.json');

    if (!mounted) return;

    setState(() {
      troncalesJson = json.decode(troncalesData);
      ramalesJson = List<String>.from(
        json.decode(ramalesData)['ramales'],
      );
    });

    print("✅ JSON INTERNO CARGADO");
  } catch (e) {
    print("❌ ERROR TOTAL CARGANDO JSON");
    print(e);
  }
}

@override
void initState() {
  super.initState();
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

  List<String> todasLasLineas() {
    final List<String> lineas = [];

    troncalesJson.forEach((troncal, subs) {
      for (final sub in subs) {
        lineas.add('$troncal / $sub');
      }
    });

    for (final ramal in ramalesJson) {
      lineas.add(ramal);
    }

    return lineas;
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
        title: const Text("Selección de Línea", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.route, size: 80, color: Color(0xFF0D47A1)),
            const SizedBox(height: 15),
            const Text(
              "Seleccione el tipo de línea a inspeccionar",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),
            DropdownButtonFormField<String>(
              value: tipoLinea,
              decoration: const InputDecoration(
                labelText: "Tipo de línea",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.merge_type),
              ),
              items: tiposLinea.map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: (valor) {
                setState(() {
                  tipoLinea = valor!;
                  if (tipoLinea == 'Troncal') {
                    troncalSeleccionada = troncalesJson.keys.first;
                    subtroncalSeleccionada = troncalesJson[troncalSeleccionada]!.first;
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
                value: troncalSeleccionada,
                decoration: const InputDecoration(
                  labelText: "Troncal",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alt_route),
                ),
                items: troncalesJson.keys.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item));
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
                value: subtroncalSeleccionada,
                decoration: const InputDecoration(
                  labelText: "Subtroncal",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_tree),
                ),
                items: List<String>.from(
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
                value: ramalSeleccionado,
                decoration: const InputDecoration(
                  labelText: "Ramal",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_tree),
                ),
                items: ramalesJson.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item));
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
              onPressed: seleccionValida
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegistroInspeccionPage(
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
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistorialPage()),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text("HISTORIAL"),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AvancePage(lineas: todasLasLineas()),
                  ),
                );
              },
              icon: const Icon(Icons.analytics),
              label: const Text("AVANCE"),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            ),
          ],
        ),
      ),
    );
  }
}
