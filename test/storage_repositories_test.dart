import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/repositories/draft_repository.dart';
import 'package:linerb/repositories/inspection_repository.dart';
import 'package:linerb/storage/draft_storage.dart';
import 'package:linerb/storage/inspection_storage.dart';
import 'package:linerb/storage/shared_preferences_storage.dart';
import 'package:linerb/storage/storage_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DraftRepository', () {
    test('guarda y carga borrador mediante el contrato de storage', () async {
      final storage = FakeDraftStorage();
      final repository = CurrentDraftRepository(storage: storage);

      final borrador = DraftData(
        usuario: 'SUPER',
        tipoLinea: 'Troncal',
        seleccionLinea: 'TRONCAL 1 / SUB 1',
        responsable: 'Operador',
        puntoReferencia: 'KM 1',
        estadoLinea: 'Operativa',
        hallazgos: [
          HallazgoInspeccion(
            tipo: 'Fuga',
            detalle: 'Activa',
            latitud: '1',
            longitud: '2',
            descripcion: 'Prueba',
          ),
        ],
      );

      await repository.guardarBorrador(borrador);
      final cargado = await repository.cargarBorrador('TRONCAL 1 / SUB 1');

      expect(cargado, isNotNull);
      expect(cargado!.responsable, 'Operador');
      expect(cargado.hallazgos.single.tipo, 'Fuga');
    });

    test('retorna null cuando el borrador no existe', () async {
      final storage = FakeDraftStorage(
        loadError: const StorageNotFoundException('sin borrador'),
      );
      final repository = CurrentDraftRepository(storage: storage);

      final cargado = await repository.cargarBorrador('LÍNEA X');

      expect(cargado, isNull);
    });

    test('propaga JSON corrupto desde SharedPreferencesStorage', () async {
      SharedPreferences.setMockInitialValues({
        'borrador_seleccionLinea': 'LÍNEA X',
        'borrador_hallazgos': ['{json-corrupto'],
      });

      final repository = CurrentDraftRepository(
        storage: const SharedPreferencesStorage(),
      );

      expect(
        repository.cargarBorrador('LÍNEA X'),
        throwsA(isA<StorageCorruptDataException>()),
      );
    });

    test('propaga error simulado de escritura', () async {
      final storage = FakeDraftStorage(
        writeError: const StorageWriteException('falló escritura'),
      );
      final repository = CurrentDraftRepository(storage: storage);

      expect(
        repository.guardarBorrador(
          const DraftData(
            usuario: 'SUPER',
            tipoLinea: 'Ramal',
            seleccionLinea: 'RAMAL 1',
            responsable: 'Operador',
            puntoReferencia: '',
            estadoLinea: 'Operativa',
            hallazgos: [],
          ),
        ),
        throwsA(isA<StorageWriteException>()),
      );
    });
  });

  group('InspectionRepository', () {
    test('agrega inspecciones y calcula última inspección desde storage', () {
      final storage = FakeInspectionStorage();
      final repository = CurrentInspectionRepository(storage: storage);
      final antigua = Inspeccion(
        linea: 'LÍNEA A',
        tipoLinea: 'Troncal',
        responsable: 'A',
        fecha: DateTime(2026, 1),
        estadoLinea: 'Operativa',
        puntoReferencia: '',
        observaciones: '',
      );
      final reciente = Inspeccion(
        linea: 'LÍNEA A',
        tipoLinea: 'Troncal',
        responsable: 'B',
        fecha: DateTime(2026, 2),
        estadoLinea: 'Operativa',
        puntoReferencia: '',
        observaciones: '',
      );

      repository.agregarInspeccion(antigua);
      repository.agregarInspeccion(reciente);

      expect(repository.obtenerInspecciones(), hasLength(2));
      expect(repository.ultimaInspeccion('LÍNEA A'), DateTime(2026, 2));
    });

    test('retorna lista vacía cuando el historial no existe', () async {
      final storage = FakeInspectionStorage(
        loadError: const StorageNotFoundException('sin historial'),
      );
      final repository = CurrentInspectionRepository(storage: storage);

      final historial = await repository.cargarHistorial();

      expect(historial, isEmpty);
    });

    test('propaga JSON corrupto del historial actual', () async {
      SharedPreferences.setMockInitialValues({
        'historial_inspecciones': ['{json-corrupto'],
      });

      final repository = CurrentInspectionRepository(
        storage: const SharedPreferencesStorage(),
      );

      expect(
        repository.cargarHistorial(),
        throwsA(isA<StorageCorruptDataException>()),
      );
    });

    test('propaga error simulado de escritura en historial', () async {
      final storage = FakeInspectionStorage(
        writeError: const StorageWriteException('falló escritura'),
      );
      final repository = CurrentInspectionRepository(storage: storage);

      expect(
        repository.guardarEnHistorial(
          Inspeccion(
            linea: 'LÍNEA A',
            tipoLinea: 'Troncal',
            responsable: 'Operador',
            fecha: DateTime(2026, 1),
            estadoLinea: 'Operativa',
            puntoReferencia: '',
            observaciones: '',
          ),
        ),
        throwsA(isA<StorageWriteException>()),
      );
    });
  });
}

class FakeDraftStorage implements DraftStorage {
  DraftData? draft;
  final Object? loadError;
  final Object? writeError;

  FakeDraftStorage({this.draft, this.loadError, this.writeError});

  @override
  Future<void> guardarBorrador(DraftData borrador) async {
    if (writeError != null) throw writeError!;
    draft = borrador;
  }

  @override
  Future<DraftData> cargarBorrador(String seleccionLinea) async {
    if (loadError != null) throw loadError!;
    final guardado = draft;

    if (guardado == null || guardado.seleccionLinea != seleccionLinea) {
      throw const StorageNotFoundException('sin borrador');
    }

    return guardado;
  }

  @override
  Future<void> borrarBorrador() async {
    if (writeError != null) throw writeError!;
    draft = null;
  }
}

class FakeInspectionStorage implements InspectionStorage {
  final List<Inspeccion> memoria;
  final List<Inspeccion> historial;
  final Object? loadError;
  final Object? writeError;

  FakeInspectionStorage({
    List<Inspeccion>? memoria,
    List<Inspeccion>? historial,
    this.loadError,
    this.writeError,
  }) : memoria = memoria ?? [],
       historial = historial ?? [];

  @override
  List<Inspeccion> obtenerInspeccionesMemoria() {
    return memoria;
  }

  @override
  void agregarInspeccionMemoria(Inspeccion inspeccion) {
    memoria.add(inspeccion);
  }

  @override
  DateTime? ultimaInspeccionMemoria(String linea) {
    final registros = memoria.where((i) => i.linea == linea).toList();

    if (registros.isEmpty) return null;

    registros.sort((a, b) => b.fecha.compareTo(a.fecha));
    return registros.first.fecha;
  }

  @override
  Future<List<Inspeccion>> cargarHistorial() async {
    if (loadError != null) throw loadError!;
    return historial;
  }

  @override
  Future<InspectionHistoryPage> cargarHistorialPage({
    String? cursor,
    int limit = 30,
  }) async {
    if (loadError != null) throw loadError!;
    final start = cursor == null ? 0 : int.tryParse(cursor) ?? 0;
    final end = start + limit > historial.length
        ? historial.length
        : start + limit;
    return InspectionHistoryPage(
      items: start >= historial.length
          ? const []
          : historial.sublist(start, end),
      nextCursor: end >= historial.length ? null : end.toString(),
      hasMore: end < historial.length,
    );
  }

  @override
  Future<void> agregarInspeccionHistorial(Inspeccion inspeccion) async {
    if (writeError != null) throw writeError!;
    historial.add(inspeccion);
  }

  @override
  Future<void> agregarInspeccionCompleta(
    Inspeccion inspeccion,
    List<HallazgoInspeccion> hallazgos,
  ) {
    return agregarInspeccionHistorial(inspeccion);
  }
}
