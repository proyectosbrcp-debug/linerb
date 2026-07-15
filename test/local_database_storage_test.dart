import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/models/draft_data.dart';
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:linerb/storage/local/local_database_storage.dart';
import 'package:linerb/storage/storage_exceptions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LinerbDatabase database;
  late LocalDatabaseStorage storage;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    storage = LocalDatabaseStorage(database: database, inspeccionesMemoria: []);
  });

  tearDown(() async {
    await database.close();
  });

  test('crea la base de datos local con las tablas iniciales', () async {
    final db = await database.open();
    final tables = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ?',
      whereArgs: ['table'],
    );

    final names = tables.map((row) => row['name']).toSet();

    expect(names, contains('inspections'));
    expect(names, contains('hallazgos'));
    expect(names, contains('draft'));
    expect(names, contains('migration_metadata'));
  });

  test('inserta y lee inspecciones desde SQLite', () async {
    final inspeccion = Inspeccion(
      linea: 'LÍNEA A',
      tipoLinea: 'Troncal',
      responsable: 'Operador',
      fecha: DateTime(2026, 1, 2),
      estadoLinea: 'Operativa',
      puntoReferencia: 'KM 1',
      observaciones: 'Sin novedad',
    );

    await storage.agregarInspeccionHistorial(inspeccion);

    final historial = await storage.cargarHistorial();

    expect(historial, hasLength(1));
    expect(historial.single.linea, 'LÍNEA A');
    expect(historial.single.fecha, DateTime(2026, 1, 2));
  });

  test('inserta y lee hallazgos asociados al borrador', () async {
    await storage.guardarBorrador(
      DraftData(
        usuario: 'SUPER',
        tipoLinea: 'Ramal',
        seleccionLinea: 'RAMAL 1',
        responsable: 'Operador',
        puntoReferencia: 'KM 2',
        estadoLinea: 'Operativa',
        hallazgos: [
          HallazgoInspeccion(
            tipo: 'Fuga',
            detalle: 'Activa',
            latitud: '1',
            longitud: '2',
            descripcion: 'Fuga visible',
          ),
          HallazgoInspeccion(
            tipo: 'Vegetación',
            detalle: 'Requiere rocería',
            latitud: '3',
            longitud: '4',
            descripcion: 'Vegetación alta',
          ),
        ],
      ),
    );

    final borrador = await storage.cargarBorrador('RAMAL 1');

    expect(await storage.hallazgoCount(), 2);
    expect(borrador.hallazgos, hasLength(2));
    expect(borrador.hallazgos.first.tipo, 'Fuga');
  });

  test('guarda, carga y borra borrador', () async {
    await storage.guardarBorrador(
      const DraftData(
        usuario: 'SUPER',
        tipoLinea: 'Troncal',
        seleccionLinea: 'TRONCAL 1 / SUB 1',
        responsable: 'Operador',
        puntoReferencia: 'KM 3',
        estadoLinea: 'Operativa',
        hallazgos: [],
      ),
    );

    final cargado = await storage.cargarBorrador('TRONCAL 1 / SUB 1');
    expect(cargado.responsable, 'Operador');

    await storage.borrarBorrador();

    expect(
      storage.cargarBorrador('TRONCAL 1 / SUB 1'),
      throwsA(isA<StorageNotFoundException>()),
    );
  });
}
