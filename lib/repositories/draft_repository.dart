import '../models/draft_data.dart';
import '../storage/draft_storage.dart';
import '../storage/storage_exceptions.dart';

export '../models/draft_data.dart';

abstract class DraftRepository {
  Future<void> guardarBorrador(DraftData borrador);

  Future<DraftData?> cargarBorrador(String seleccionLinea);

  Future<void> borrarBorrador();
}

class CurrentDraftRepository implements DraftRepository {
  final DraftStorage storage;

  const CurrentDraftRepository({required this.storage});

  @override
  Future<void> guardarBorrador(DraftData borrador) {
    return storage.guardarBorrador(borrador);
  }

  @override
  Future<DraftData?> cargarBorrador(String seleccionLinea) async {
    try {
      return await storage.cargarBorrador(seleccionLinea);
    } on StorageNotFoundException {
      return null;
    }
  }

  @override
  Future<void> borrarBorrador() {
    return storage.borrarBorrador();
  }
}
