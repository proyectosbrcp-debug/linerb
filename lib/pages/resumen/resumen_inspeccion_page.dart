import 'dart:async';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../controllers/inspection_registration_controller.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/utils/date_utils.dart';
import '../../models/hallazgo_inspeccion.dart';
import '../../models/inspeccion.dart';
import '../../repositories/inspection_repository.dart';
import '../../services/findings_map_service.dart';
import '../../services/inspection_pdf_service.dart';
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
  final FindingsMapImageProvider? mapImageProvider;

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
    this.mapImageProvider,
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
  late final InspectionPdfService pdfService;
  late TextEditingController observacionGeneralController;

  @override
  void initState() {
    super.initState();
    pdfService = InspectionPdfService(
      photoPathResolver: photoService.pdfPhotoPaths,
      mapImageProvider:
          widget.mapImageProvider ?? GoogleStaticFindingsMapImageProvider(),
    );
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
                unawaited(
                  AppDependencies.automaticSyncCoordinator
                      .notifyInspectionFinalized(),
                );

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
    final pdfBytes = await pdfService.buildPdf(
      InspectionPdfData(
        usuario: widget.usuario,
        tipoLinea: widget.tipoLinea,
        seleccionLinea: widget.seleccionLinea,
        responsable: widget.responsable,
        estadoLinea: widget.estadoLinea,
        puntoReferencia: widget.puntoReferencia,
        observaciones: observacionGeneralController.text,
        hallazgos: widget.hallazgos,
        generatedAt: DateTime.now(),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
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
