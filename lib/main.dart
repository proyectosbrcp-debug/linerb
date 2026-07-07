import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const LinerbApp());
}

String fechaCorta(DateTime fecha) {
  return "${fecha.day}/${fecha.month}/${fecha.year}";
}

class Inspeccion {
  final String linea;
  final String tipoLinea;
  final String responsable;
  final DateTime fecha;
  final String estadoLinea;
  final String puntoReferencia;
  final String observaciones;

  Inspeccion({
    required this.linea,
    required this.tipoLinea,
    required this.responsable,
    required this.fecha,
    required this.estadoLinea,
    required this.puntoReferencia,
    required this.observaciones,
  });
}

class DatosApp {
  static final List<Inspeccion> inspecciones = [];
}

class LinerbApp extends StatelessWidget {
  const LinerbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LINERB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0D47A1),
        useMaterial3: true,
      ),
      home: const InicioPage(),
    );
  }
}

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  String usuario = 'SUPER';
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final fecha = fechaCorta(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: const Text("LINERB", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.hub, size: 90, color: Color(0xFF0D47A1)),
            const SizedBox(height: 15),
            const Text(
              "Sistema de Inspección de Líneas",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text("Fecha"),
                subtitle: Text(fecha),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: usuario,
              decoration: const InputDecoration(
                labelText: "Usuario",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "SUPER", child: Text("SUPER")),
                DropdownMenuItem(value: "INSPE", child: Text("INSPE")),
              ],
              onChanged: (valor) {
                setState(() {
                  usuario = valor!;
                });
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Contraseña",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                final accesoSuper =
                    usuario == "SUPER" && passwordController.text == "ECO01";
                final accesoInspe =
                    usuario == "INSPE" && passwordController.text == "MASA01";

                if (accesoSuper || accesoInspe) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SeleccionLineaPage(usuario: usuario),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Usuario o contraseña incorrectos")),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text("INICIAR"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      Uri.parse('https://linerb.web.app/troncales.json'),
    );

    final ramalesResponse = await http.get(
      Uri.parse('https://linerb.web.app/ramales.json'),
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
class HallazgoInspeccion {
  final String tipo;
  final String detalle;
  final String latitud;
  final String longitud;
  final String descripcion;
  final String? foto1Path;
  final String? foto2Path;

  HallazgoInspeccion({
    required this.tipo,
    required this.detalle,
    required this.latitud,
    required this.longitud,
    required this.descripcion,
    this.foto1Path,
    this.foto2Path,
  });

  @override
  String toString() {
    final titulo = detalle.isEmpty ? tipo : "$tipo - $detalle";
    return "$titulo\nCoordenadas: $latitud, $longitud\nFotos: FOTO 1  FOTO 2\nDescripción: $descripcion";
  }
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

class ResumenInspeccionPage extends StatefulWidget {
  final String usuario;
  final String tipoLinea;
  final String seleccionLinea;
  final String responsable;
  final String estadoLinea;
  final String puntoReferencia;
  final String latitud;
  final String longitud;
  final String observaciones;
  final List<HallazgoInspeccion> hallazgos;
  final String soporteEstado;
  final String valvulaEstado;
  final String vegetacionEstado;
  final String fugaEstado;

  const ResumenInspeccionPage({
    super.key,
    required this.usuario,
    required this.tipoLinea,
    required this.seleccionLinea,
    required this.responsable,
    required this.estadoLinea,
    required this.puntoReferencia,
    required this.latitud,
    required this.longitud,
    required this.observaciones,
    required this.hallazgos,
    required this.soporteEstado,
    required this.valvulaEstado,
    required this.vegetacionEstado,
    required this.fugaEstado,
  });

  @override
  State<ResumenInspeccionPage> createState() => _ResumenInspeccionPageState();
}

class _ResumenInspeccionPageState extends State<ResumenInspeccionPage> {
  late TextEditingController observacionGeneralController;

  @override
  void initState() {
    super.initState();
    observacionGeneralController =
        TextEditingController(text: widget.observaciones);
  }

  @override
  void dispose() {
    observacionGeneralController.dispose();
    super.dispose();
  }

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
          "Resumen de Inspección",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card("Fecha", fecha, Icons.calendar_month),
            _card("Responsable", widget.responsable, Icons.person),
            _card("Usuario de acceso", widget.usuario, Icons.verified_user),
            _card("Tipo de línea", widget.tipoLinea, Icons.route),
            _card("Línea seleccionada", widget.seleccionLinea, Icons.account_tree),
            _card(
              "Punto de referencia",
              widget.puntoReferencia.isEmpty
                  ? "No registrado"
                  : widget.puntoReferencia,
              Icons.place,
            ),
            _card("Estado operativo", widget.estadoLinea, Icons.health_and_safety),
            _card(
              "Latitud",
              widget.latitud.isEmpty ? "No registrada" : widget.latitud,
              Icons.my_location,
            ),
            _card(
              "Longitud",
              widget.longitud.isEmpty ? "No registrada" : widget.longitud,
              Icons.explore,
            ),
            const SizedBox(height: 12),
            const Text(
              "Hallazgos seleccionados",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: widget.hallazgos.isEmpty
                    ? const Text("Sin hallazgos registrados")
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.hallazgos.map((h) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF0D47A1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  h.detalle.isEmpty
                                      ? h.tipo
                                      : "${h.tipo} - ${h.detalle}",
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text("Coordenadas: ${h.latitud}, ${h.longitud}"),
                                const SizedBox(height: 6),
                                const Text("Fotos: FOTO 1  FOTO 2"),
                                const SizedBox(height: 6),
                                Text("Descripción: ${h.descripcion}"),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: observacionGeneralController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Observación general de la inspección",
                hintText: "Escriba una observación final antes de guardar...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: () async {
                await generarPdf();
                if (!mounted) return;

                final nuevaInspeccion = Inspeccion(
                  linea: widget.seleccionLinea,
                  tipoLinea: widget.tipoLinea,
                  responsable: widget.responsable,
                  fecha: DateTime.now(),
                  estadoLinea: widget.estadoLinea,
                  puntoReferencia: widget.puntoReferencia,
                  observaciones: observacionGeneralController.text.trim(),
                );

                DatosApp.inspecciones.add(nuevaInspeccion);

                final prefs = await SharedPreferences.getInstance();
                final historialActual =
                    prefs.getStringList('historial_inspecciones') ?? [];

                final registroJson = jsonEncode({
                  'linea': nuevaInspeccion.linea,
                  'tipoLinea': nuevaInspeccion.tipoLinea,
                  'responsable': nuevaInspeccion.responsable,
                  'fecha': nuevaInspeccion.fecha.toIso8601String(),
                  'estadoLinea': nuevaInspeccion.estadoLinea,
                  'puntoReferencia': nuevaInspeccion.puntoReferencia,
                  'observaciones': nuevaInspeccion.observaciones,
                });

                historialActual.add(registroJson);

                await prefs.setStringList(
                  'historial_inspecciones',
                  historialActual,
                );

                final prefsBorrador = await SharedPreferences.getInstance();

await prefsBorrador.remove('borrador_usuario');
await prefsBorrador.remove('borrador_tipoLinea');
await prefsBorrador.remove('borrador_seleccionLinea');
await prefsBorrador.remove('borrador_responsable');
await prefsBorrador.remove('borrador_puntoReferencia');
await prefsBorrador.remove('borrador_estadoLinea');
await prefsBorrador.remove('borrador_hallazgos');

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Inspección guardada permanentemente"),
                  ),
                );

                Navigator.pop(context);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.save),
              label: const Text("CONFIRMAR Y GUARDAR"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
              ),
            ),
          ],
        ),
      ),
    );
  }
Future<void> generarPdf() async {
  final logoLinerb = pw.MemoryImage(
  (await rootBundle.load('assets/logo_linerb.png')).buffer.asUint8List(),
);
final footerFranjas = pw.MemoryImage(
  (await rootBundle.load('assets/footer_linerb.png')).buffer.asUint8List(),
);

final footerTuberia = pw.MemoryImage(
  (await rootBundle.load('assets/footer_linerb-1.png')).buffer.asUint8List(),
);
  final pdf = pw.Document();
  final Map<HallazgoInspeccion, List<pw.MemoryImage>> fotosPdf = {};

for (final h in widget.hallazgos) {
  final List<pw.MemoryImage> fotos = [];

  if (h.foto1Path != null && File(h.foto1Path!).existsSync()) {
    fotos.add(pw.MemoryImage(await File(h.foto1Path!).readAsBytes()));
  }

  if (h.foto2Path != null && File(h.foto2Path!).existsSync()) {
    fotos.add(pw.MemoryImage(await File(h.foto2Path!).readAsBytes()));
  }

  fotosPdf[h] = fotos;
}

  pdf.addPage(
    pw.MultiPage(
  pageTheme: pw.PageTheme(
  pageFormat: PdfPageFormat.a4,
  margin: const pw.EdgeInsets.fromLTRB(35, 35, 35, 120),
  buildBackground: (context) {
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 0,
            bottom: 0,
            child: pw.Image(
              footerFranjas,
              width: 220,
            ),
          ),
          pw.Positioned(
            right: 0,
            bottom: 0,
            child: pw.Image(
              footerTuberia,
              width: 320,
            ),
          ),
        ],
      ),
    );
  },
),

build: (context) => [
        pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Image(logoLinerb, width: 140),
    pw.SizedBox(width: 25),
    pw.Container(width: 1.5, height: 70, color: PdfColors.green700),
    pw.SizedBox(width: 25),
    pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'INFORME DE LINERB',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Inspección de Líneas y Ramales',
            style: const pw.TextStyle(fontSize: 13),
          ),
        ],
      ),
    ),
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('No. Informe: LIN-${DateTime.now().millisecondsSinceEpoch}'),
        pw.Text('Fecha: ${fechaCorta(DateTime.now())}'),
        pw.Text('Versión: 1.0'),
        pw.Text('Página: 1'),
      ],
    ),
  ],
),

pw.SizedBox(height: 12),

pw.Container(
  height: 2,
  color: PdfColors.green900,
),

        pw.SizedBox(height: 10),

        pw.Container(
  padding: const pw.EdgeInsets.all(10),
  decoration: pw.BoxDecoration(
    border: pw.Border.all(color: PdfColors.green900),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: PdfColors.green900,
        child: pw.Text(
          '1. INFORMACIÓN GENERAL',
          style: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Fecha: ${fechaCorta(DateTime.now())}'),
                pw.Text('Responsable: ${widget.responsable}'),
                pw.Text('Usuario: ${widget.usuario}'),
                pw.Text('Tipo de línea: ${widget.tipoLinea}'),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Línea: ${widget.seleccionLinea}'),
                pw.Text('Punto de referencia: ${widget.puntoReferencia}'),
                pw.Text('Estado operativo: ${widget.estadoLinea}'),
                pw.Text('Total hallazgos: ${widget.hallazgos.length}'),
              ],
            ),
          ),
        ],
      ),
    ],
  ),
),

        pw.SizedBox(height: 15),

        pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  color: PdfColors.green900,
  child: pw.Text(
    '2. HALLAZGOS REGISTRADOS',
    style: pw.TextStyle(
      color: PdfColors.white,
      fontWeight: pw.FontWeight.bold,
    ),
  ),
),

        pw.SizedBox(height: 10),

        ...widget.hallazgos.map(
          (h) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
  border: pw.Border.all(
    color: PdfColors.green900,
    width: 1,
  ),
),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  h.detalle.isEmpty
                      ? h.tipo
                      : '${h.tipo} - ${h.detalle}',
                ),
                pw.Text('Latitud: ${h.latitud}'),
pw.Text('Longitud: ${h.longitud}'),
pw.Text('Descripción: ${h.descripcion}'),

if ((fotosPdf[h] ?? []).isNotEmpty) ...[
  pw.SizedBox(height: 8),
  pw.Wrap(
    spacing: 8,
    runSpacing: 8,
    children: (fotosPdf[h] ?? []).map((foto) {
      return pw.Container(
        width: 180,
        height: 130,
        child: pw.Image(foto, fit: pw.BoxFit.cover),
      );
    }).toList(),
  ),
],
              ],
            ),
          ),
        ),

        pw.SizedBox(height: 15),

        pw.SizedBox(height: 20),

pw.Text(
  'OBSERVACIÓN GENERAL',
  style: pw.TextStyle(
    fontSize: 16,
    fontWeight: pw.FontWeight.bold,
  ),
),

pw.SizedBox(height: 8),

pw.Text(
  observacionGeneralController.text,
),

      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
  );
}
  Widget _card(String titulo, String contenido, IconData icono) {
    return Card(
      child: ListTile(
        leading: Icon(icono),
        title: Text(titulo),
        subtitle: Text(contenido),
      ),
    );
  }
}

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
