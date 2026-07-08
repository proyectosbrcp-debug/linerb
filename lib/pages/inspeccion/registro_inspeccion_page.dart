import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/date_utils.dart';
import '../../models/hallazgo_inspeccion.dart';
import '../resumen/resumen_inspeccion_page.dart';

class RegistroInspeccionPage extends StatefulWidget {
  final String usuario;
  final String tipoLinea;
  final String seleccionLinea;

  const RegistroInspeccionPage({
    super.key,
    required this.usuario,
    required this.tipoLinea,
    required this.seleccionLinea,
  });

  @override
  State<RegistroInspeccionPage> createState() => _RegistroInspeccionPageState();
}
class _RegistroInspeccionPageState extends State<RegistroInspeccionPage> {
  String estadoLinea = 'Operativa';

  String hallazgoSeleccionado = 'Corrosión';

  String soporteEstado = 'Buen estado';
  String valvulaEstado = 'Operativa';
  String vegetacionEstado = 'Requiere rocería';
  String fugaEstado = 'Activa';
  final List<HallazgoInspeccion> hallazgosRegistrados = [];
  File? foto1;
File? foto2;

final ImagePicker picker = ImagePicker();

  final TextEditingController responsableController = TextEditingController();
  final TextEditingController puntoReferenciaController = TextEditingController();
  final TextEditingController latitudController = TextEditingController();
  final TextEditingController longitudController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();
  Future<void> guardarBorradorLocal() async {
  final prefs = await SharedPreferences.getInstance();

  final hallazgosJson = hallazgosRegistrados.map((h) {
    return jsonEncode({
      'tipo': h.tipo,
      'detalle': h.detalle,
      'latitud': h.latitud,
      'longitud': h.longitud,
      'descripcion': h.descripcion,
      'foto1Path': h.foto1Path,
      'foto2Path': h.foto2Path,
    });
  }).toList();

  await prefs.setString('borrador_usuario', widget.usuario);
  await prefs.setString('borrador_tipoLinea', widget.tipoLinea);
  await prefs.setString('borrador_seleccionLinea', widget.seleccionLinea);
  await prefs.setString('borrador_responsable', responsableController.text);
  await prefs.setString('borrador_puntoReferencia', puntoReferenciaController.text);
  await prefs.setString('borrador_estadoLinea', estadoLinea);
  await prefs.setStringList('borrador_hallazgos', hallazgosJson);
}

Future<void> cargarBorradorLocal() async {
  final prefs = await SharedPreferences.getInstance();

  if (!mounted) return;

  final seleccionGuardada = prefs.getString('borrador_seleccionLinea');

  if (seleccionGuardada == null || seleccionGuardada != widget.seleccionLinea) {
    return;
  }

  responsableController.text = prefs.getString('borrador_responsable') ?? '';
  puntoReferenciaController.text = prefs.getString('borrador_puntoReferencia') ?? '';
  estadoLinea = prefs.getString('borrador_estadoLinea') ?? 'Operativa';

  final hallazgosJson = prefs.getStringList('borrador_hallazgos') ?? [];

  hallazgosRegistrados.clear();

  for (final item in hallazgosJson) {
    final data = jsonDecode(item);

    hallazgosRegistrados.add(
      HallazgoInspeccion(
        tipo: data['tipo'] ?? '',
        detalle: data['detalle'] ?? '',
        latitud: data['latitud'] ?? '',
        longitud: data['longitud'] ?? '',
        descripcion: data['descripcion'] ?? '',
        foto1Path: data['foto1Path'],
        foto2Path: data['foto2Path'],
      ),
    );
  }

  setState(() {});
}

Future<void> borrarBorradorLocal() async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.remove('borrador_usuario');
  await prefs.remove('borrador_tipoLinea');
  await prefs.remove('borrador_seleccionLinea');
  await prefs.remove('borrador_responsable');
  await prefs.remove('borrador_puntoReferencia');
  await prefs.remove('borrador_estadoLinea');
  await prefs.remove('borrador_hallazgos');
}
@override
void initState() {
  super.initState();
  cargarBorradorLocal();
}
  Future<void> tomarFoto1() async {
  final XFile? imagen = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 80,
  );

  if (!mounted) return;

  if (imagen != null) {
    setState(() {
      foto1 = File(imagen.path);
    });
  }
}

Future<void> tomarFoto2() async {
  final XFile? imagen = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 80,
  );

  if (!mounted) return;

  if (imagen != null) {
    setState(() {
      foto2 = File(imagen.path);
    });
  }
}

Future<void> obtenerCoordenadas() async {
  bool servicioActivo;
  LocationPermission permiso;

  servicioActivo = await Geolocator.isLocationServiceEnabled();
  if (!mounted) return;

  if (!servicioActivo) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Active el GPS del dispositivo")),
    );
    return;
  }

  permiso = await Geolocator.checkPermission();
  if (!mounted) return;

  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
    if (!mounted) return;
  }

  if (permiso == LocationPermission.deniedForever ||
      permiso == LocationPermission.denied) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Permiso de ubicación denegado")),
    );
    return;
  }

  final posicion = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  if (!mounted) return;

  setState(() {
    latitudController.text = posicion.latitude.toString();
    longitudController.text = posicion.longitude.toString();
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Coordenadas obtenidas correctamente")),
  );
}

  final List<String> hallazgos = [
    'Corrosión',
    'Fuga',
    'Soportería',
    'Vegetación',
    'Válvulas',
    'Recubrimiento',
    'Terceros',
    'Erosión',
    'Socavación',
    'Instrumentación',
    'Acceso restringido',
  ];

  @override
  Widget build(BuildContext context) {
    final fecha = fechaCorta(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: const Text(
          "Registro de Inspección",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.route),
                title: Text(widget.tipoLinea),
                subtitle: Text(widget.seleccionLinea),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text("Fecha de inspección"),
                subtitle: Text(fecha),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: responsableController,
              decoration: const InputDecoration(
                labelText: "Responsable de la inspección",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: puntoReferenciaController,
              decoration: const InputDecoration(
                labelText: "Kilómetro / Punto de referencia",
                hintText: "Ejemplo: KM 12+350, válvula, cruce o cluster",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: estadoLinea,
              decoration: const InputDecoration(
                labelText: "Estado operativo de la línea",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.health_and_safety),
              ),
              items: const [
                DropdownMenuItem(value: "Operativa", child: Text("Operativa")),
                DropdownMenuItem(
                  value: "Operativa con Hallazgos",
                  child: Text("Operativa con Hallazgos"),
                ),
                DropdownMenuItem(value: "Intervenida", child: Text("Intervenida")),
                DropdownMenuItem(
                  value: "Fuera de Servicio",
                  child: Text("Fuera de Servicio"),
                ),
              ],
              onChanged: (valor) {
                setState(() {
                  estadoLinea = valor!;
                });
              },
            ),
            const SizedBox(height: 22),
            const Text(
              "Hallazgo técnico principal",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: hallazgos.map((item) {
                  return RadioListTile<String>(
                    title: Text(item),
                    value: item,
                    groupValue: hallazgoSeleccionado,
                    onChanged: (valor) {
                      setState(() {
                        hallazgoSeleccionado = valor!;
                      });
                    },
                  );
                }).toList(),
              ),
            ),

            if (hallazgoSeleccionado == 'Vegetación') ...[
              const SizedBox(height: 18),
              _dropdownDetalle(
                label: "Condición de vegetación",
                icon: Icons.grass,
                value: vegetacionEstado,
                opciones: const [
                  "Requiere rocería",
                  "Árbol afectando línea",
                ],
                onChanged: (valor) {
                  setState(() {
                    vegetacionEstado = valor!;
                  });
                },
              ),
            ],

            if (hallazgoSeleccionado == 'Fuga') ...[
              const SizedBox(height: 18),
              _dropdownDetalle(
                label: "Estado de la fuga",
                icon: Icons.water_drop,
                value: fugaEstado,
                opciones: const [
                  "Activa",
                  "Controlada",
                  "Histórica",
                ],
                onChanged: (valor) {
                  setState(() {
                    fugaEstado = valor!;
                  });
                },
              ),
            ],

            if (hallazgoSeleccionado == 'Soportería') ...[
              const SizedBox(height: 18),
              _dropdownDetalle(
                label: "Estado de soportería",
                icon: Icons.construction,
                value: soporteEstado,
                opciones: const [
                  "Buen estado",
                  "Mal estado",
                ],
                onChanged: (valor) {
                  setState(() {
                    soporteEstado = valor!;
                  });
                },
              ),
            ],

            if (hallazgoSeleccionado == 'Válvulas') ...[
              const SizedBox(height: 18),
              _dropdownDetalle(
                label: "Estado de válvula",
                icon: Icons.settings_input_component,
                value: valvulaEstado,
                opciones: const [
                  "Operativa",
                  "No operativa",
                  "Requiere mantenimiento",
                  "Válvula de corte",
                ],
                onChanged: (valor) {
                  setState(() {
                    valvulaEstado = valor!;
                  });
                },
              ),
            ],

           const SizedBox(height: 22),

const Text(
  "Ubicación GPS",
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 10),

ElevatedButton.icon(
  onPressed: obtenerCoordenadas,
  icon: const Icon(Icons.gps_fixed),
  label: const Text("OBTENER COORDENADAS"),
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, 52),
  ),
),

const SizedBox(height: 12),
            TextField(
              controller: latitudController,
              readOnly: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Latitud",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.my_location),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: longitudController,
              readOnly: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Longitud",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.explore),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
  onPressed: tomarFoto1,
  icon: const Icon(Icons.camera_alt),
  label: Text(
    foto1 == null
        ? "TOMAR FOTO 1"
        : "FOTO 1 CAPTURADA",
  ),
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, 52),
  ),
),

const SizedBox(height: 10),

ElevatedButton.icon(
  onPressed: tomarFoto2,
  icon: const Icon(Icons.camera_alt),
  label: Text(
    foto2 == null
        ? "TOMAR FOTO 2"
        : "FOTO 2 CAPTURADA",
  ),
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, 52),
  ),
),
            const SizedBox(height: 22),
            TextField(
              controller: observacionesController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "Observaciones",
                hintText: "Describa las novedades encontradas en campo...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 22),
           OutlinedButton.icon(
  onPressed: () {
    if (latitudController.text.trim().isEmpty ||
        longitudController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debe ingresar coordenadas del hallazgo"),
        ),
      );
      return;
    }

    if (observacionesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debe ingresar descripción del hallazgo"),
        ),
      );
      return;
    }

    String detalle = "";

    if (hallazgoSeleccionado == "Vegetación") {
      detalle = vegetacionEstado;
    } else if (hallazgoSeleccionado == "Fuga") {
      detalle = fugaEstado;
    } else if (hallazgoSeleccionado == "Soportería") {
      detalle = soporteEstado;
    } else if (hallazgoSeleccionado == "Válvulas") {
      detalle = valvulaEstado;
    }

    final nuevoHallazgo = HallazgoInspeccion(
      tipo: hallazgoSeleccionado,
      detalle: detalle,
      latitud: latitudController.text.trim(),
      longitud: longitudController.text.trim(),
      descripcion: observacionesController.text.trim(),
      foto1Path: foto1?.path,
      foto2Path: foto2?.path,
    );

    setState(() {
      hallazgosRegistrados.add(nuevoHallazgo);

      latitudController.clear();
      longitudController.clear();
      observacionesController.clear();
      foto1 = null;
foto2 = null;
    });

    guardarBorradorLocal();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Hallazgo agregado: ${nuevoHallazgo.tipo}",
        ),
      ),
    );
  },
  icon: const Icon(Icons.drafts),
  label: const Text("AGREGAR HALLAZGO A BORRADOR"),
  style: OutlinedButton.styleFrom(
    minimumSize: const Size(double.infinity, 52),
  ),
),
              const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () {
                if (responsableController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Debe ingresar el responsable de la inspección"),
                    ),
                  );
                  return;
                }

                final hallazgosSeleccionados = hallazgosRegistrados;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResumenInspeccionPage(
                      usuario: widget.usuario,
                      tipoLinea: widget.tipoLinea,
                      seleccionLinea: widget.seleccionLinea,
                      responsable: responsableController.text.trim(),
                      estadoLinea: estadoLinea,
                      puntoReferencia: puntoReferenciaController.text,
                      latitud: latitudController.text,
                      longitud: longitudController.text,
                      observaciones: observacionesController.text,
                      hallazgos: hallazgosSeleccionados,
                      soporteEstado: soporteEstado,
                      valvulaEstado: valvulaEstado,
                      vegetacionEstado: vegetacionEstado,
                      fugaEstado: fugaEstado,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.check_circle),
              label: const Text("FINALIZAR INSPECCIÓN"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _dropdownDetalle({
    required String label,
    required IconData icon,
    required String value,
    required List<String> opciones,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      items: opciones.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }
}
