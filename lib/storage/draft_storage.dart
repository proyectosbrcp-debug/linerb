import '../models/draft_data.dart';

abstract class DraftStorage {
  Future<void> guardarBorrador(DraftData borrador);

  Future<DraftData> cargarBorrador(String seleccionLinea);

  Future<void> borrarBorrador();
}
