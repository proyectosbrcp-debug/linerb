import 'package:flutter/material.dart';

import '../../controllers/history_controller.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/theme/ui_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../models/inspeccion.dart';
import '../../widgets/linerb_empty_state.dart';
import '../../widgets/linerb_loading_state.dart';

class HistorialPage extends StatefulWidget {
  const HistorialPage({super.key});

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  final HistoryController historyController =
      AppDependencies.historyController();
  final ScrollController _scrollController = ScrollController();
  List<Inspeccion> inspecciones = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    cargarHistorial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> cargarHistorial() async {
    await historyController.cargarPrimeraPagina();

    if (!mounted) return;

    setState(() {
      inspecciones = List.of(historyController.inspecciones);
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !historyController.hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await historyController.cargarSiguientePagina();

    if (!mounted) return;

    setState(() {
      inspecciones = List.of(historyController.inspecciones);
      _isLoadingMore = false;
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 300) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LinerbColors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: LinerbColors.primaryBlue,
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
              style: LinerbTextStyles.screenTitle,
            ),
            const SizedBox(height: LinerbSpacing.xl),
            Expanded(
              child: _isLoading
                  ? const LinerbLoadingState(
                      message: 'Cargando historial de inspecciones...',
                    )
                  : inspecciones.isEmpty
                  ? const LinerbEmptyState(
                      icon: Icons.history,
                      title: 'Sin inspecciones registradas',
                      message:
                          'Cuando finalice una inspección aparecerá en este historial.',
                    )
                  : ListView.builder(
                      controller: _scrollController,
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
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.only(top: LinerbSpacing.sm),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
