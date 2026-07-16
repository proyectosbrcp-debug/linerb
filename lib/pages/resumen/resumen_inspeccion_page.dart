import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inspection_registration_controller.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/utils/date_utils.dart';
import '../../models/hallazgo_inspeccion.dart';
import '../../models/inspeccion.dart';
import '../../repositories/inspection_repository.dart';
import '../../services/local_photo_service.dart';

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
  final InspectionRepository inspectionRepository =
      AppDependencies.inspectionRepository;
  final InspectionRegistrationController registroController =
      AppDependencies.inspectionRegistrationController();
  final LocalPhotoService photoService = AppDependencies.localPhotoService;
  late TextEditingController observacionGeneralController;

  @override
  void initState() {
    super.initState();
    observacionGeneralController = TextEditingController(
      text: widget.observaciones,
    );
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
            _card(
              "Línea seleccionada",
              widget.seleccionLinea,
              Icons.account_tree,
            ),
            _card(
              "Punto de referencia",
              widget.puntoReferencia.isEmpty
                  ? "No registrado"
                  : widget.puntoReferencia,
              Icons.place,
            ),
            _card(
              "Estado operativo",
              widget.estadoLinea,
              Icons.health_and_safety,
            ),
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
                              border: Border.all(
                                color: const Color(0xFF0D47A1),
                              ),
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
                                Text(
                                  "Coordenadas: ${h.latitud}, ${h.longitud}",
                                ),
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

                inspectionRepository.agregarInspeccion(nuevaInspeccion);

                await inspectionRepository.guardarInspeccionCompleta(
                  nuevaInspeccion,
                  widget.hallazgos,
                );

                await registroController.borrarBorrador();

                if (!context.mounted) return;

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
      (await rootBundle.load(
        'assets/footer_linerb-1.png',
      )).buffer.asUint8List(),
    );
    final pdf = pw.Document();
    final Map<HallazgoInspeccion, List<pw.MemoryImage>> fotosPdf = {};

    for (final h in widget.hallazgos) {
      final List<pw.MemoryImage> fotos = [];
      final photoPaths = await photoService.pdfPhotoPaths(h);

      for (final photoPath in photoPaths) {
        fotos.add(pw.MemoryImage(await File(photoPath).readAsBytes()));
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
                    child: pw.Image(footerFranjas, width: 220),
                  ),
                  pw.Positioned(
                    right: 0,
                    bottom: 0,
                    child: pw.Image(footerTuberia, width: 320),
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
                  pw.Text(
                    'No. Informe: LIN-${DateTime.now().millisecondsSinceEpoch}',
                  ),
                  pw.Text('Fecha: ${fechaCorta(DateTime.now())}'),
                  pw.Text('Versión: 1.0'),
                  pw.Text('Página: 1'),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 12),

          pw.Container(height: 2, color: PdfColors.green900),

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
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                          pw.Text(
                            'Punto de referencia: ${widget.puntoReferencia}',
                          ),
                          pw.Text('Estado operativo: ${widget.estadoLinea}'),
                          pw.Text(
                            'Total hallazgos: ${widget.hallazgos.length}',
                          ),
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
                border: pw.Border.all(color: PdfColors.green900, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    h.detalle.isEmpty ? h.tipo : '${h.tipo} - ${h.detalle}',
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
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),

          pw.SizedBox(height: 8),

          pw.Text(observacionGeneralController.text),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
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
