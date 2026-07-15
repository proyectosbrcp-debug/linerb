import '../repositories/draft_repository.dart';

class InspectionRegistrationController {
  final DraftRepository draftRepository;

  const InspectionRegistrationController({
    this.draftRepository = const CurrentDraftRepository(),
  });

  Future<void> guardarBorrador(DraftData borrador) {
    return draftRepository.guardarBorrador(borrador);
  }

  Future<DraftData?> cargarBorrador(String seleccionLinea) {
    return draftRepository.cargarBorrador(seleccionLinea);
  }

  Future<void> borrarBorrador() {
    return draftRepository.borrarBorrador();
  }

  String detalleHallazgo({
    required String hallazgoSeleccionado,
    required String vegetacionEstado,
    required String fugaEstado,
    required String soporteEstado,
    required String valvulaEstado,
  }) {
    if (hallazgoSeleccionado.startsWith("Vegetaci")) {
      return vegetacionEstado;
    } else if (hallazgoSeleccionado == "Fuga") {
      return fugaEstado;
    } else if (hallazgoSeleccionado.startsWith("Soporter")) {
      return soporteEstado;
    } else if (hallazgoSeleccionado.endsWith("lvulas")) {
      return valvulaEstado;
    }

    return "";
  }
}
