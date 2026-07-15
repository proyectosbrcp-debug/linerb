import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/core/runtime/app_runtime_initializer.dart';
import 'package:linerb/models/draft_data.dart';
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/repositories/inspection_repository.dart';
import 'package:linerb/storage/fallback_inspection_storage.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:linerb/storage/local/local_database_storage.dart';
import 'package:linerb/storage/migration/v1_data_migration_service.dart';
import 'package:linerb/storage/shared_preferences_storage.dart';
import 'package:linerb/storage/storage_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LinerbDatabase database;
  late List<Inspeccion> memoria;
  late LocalDatabaseStorage localStorage;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    memoria = [];
    database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    localStorage = LocalDatabaseStorage(
      database: database,
      inspeccionesMemoria: memoria,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('arranque sin datos V1 queda ready y activa SQLite', () async {
    final initializer = _initializer(database, localStorage);

    final result = await initializer.initialize();

    expect(result.status, RuntimeInitializationStatus.ready);
    expect(
      await localStorage.isMigrationCompleted('v1_shared_preferences'),
      isTrue,
    );
  });

  test('arranque con datos V1 válidos migra y usa SQLite', () async {
    SharedPreferences.setMockInitialValues(_legacyValues());
    final initializer = _initializer(database, localStorage);

    final result = await initializer.initialize();

    expect(result.status, RuntimeInitializationStatus.ready);
    expect(await localStorage.inspectionCount(), 1);
    expect(memoria.single.linea, 'LÍNEA A');

    final repository = CurrentInspectionRepository(
      storage: FallbackInspectionStorage(
        localStorage: localStorage,
        legacyStorage: const SharedPreferencesStorage(inspeccionesMemoria: []),
        migrationTarget: localStorage,
      ),
    );

    final historial = await repository.cargarHistorial();
    expect(historial.single.linea, 'LÍNEA A');
    expect(repository.ultimaInspeccion('LÍNEA A'), DateTime(2026, 1, 2));
  });

  test('migración fallida queda degraded y el fallback conserva V1', () async {
    SharedPreferences.setMockInitialValues(_legacyValues());
    final initializer = AppRuntimeInitializer(
      openDatabase: () async {
        await database.open();
      },
      migrate: () {
        throw Exception('fallo simulado');
      },
    );

    final result = await initializer.initialize();

    expect(result.status, RuntimeInitializationStatus.degraded);

    final repository = CurrentInspectionRepository(
      storage: FallbackInspectionStorage(
        localStorage: localStorage,
        legacyStorage: const SharedPreferencesStorage(inspeccionesMemoria: []),
        migrationTarget: localStorage,
      ),
    );

    final historial = await repository.cargarHistorial();
    expect(historial.single.linea, 'LÍNEA A');
  });

  test('SQLite no disponible queda degraded', () async {
    final initializer = AppRuntimeInitializer(
      openDatabase: () {
        throw Exception('sqlite no disponible');
      },
      migrate: () async {},
      timeout: const Duration(milliseconds: 100),
    );

    final result = await initializer.initialize();

    expect(result.status, RuntimeInitializationStatus.degraded);
  });

  test('guardado completo persiste inspección y hallazgos en SQLite', () async {
    final repository = CurrentInspectionRepository(storage: localStorage);
    final inspeccion = Inspeccion(
      linea: 'LÍNEA B',
      tipoLinea: 'Troncal',
      responsable: 'Operador',
      fecha: DateTime(2026, 3, 4),
      estadoLinea: 'Operativa',
      puntoReferencia: 'KM 3',
      observaciones: 'Finalizada',
    );

    await repository.guardarInspeccionCompleta(inspeccion, [
      HallazgoInspeccion(
        tipo: 'Fuga',
        detalle: 'Activa',
        latitud: '1',
        longitud: '2',
        descripcion: 'Hallazgo',
      ),
    ]);

    expect(await localStorage.inspectionCount(), 1);
    expect(await localStorage.hallazgoCountForInspection('LÍNEA B'), 1);
  });

  test('persistencia y restauración de borrador en SQLite', () async {
    await localStorage.guardarBorrador(
      DraftData(
        usuario: 'SUPER',
        tipoLinea: 'Ramal',
        seleccionLinea: 'RAMAL 1',
        responsable: 'Operador',
        puntoReferencia: 'KM 5',
        estadoLinea: 'Operativa',
        hallazgos: [
          HallazgoInspeccion(
            tipo: 'Vegetación',
            detalle: 'Requiere rocería',
            latitud: '3',
            longitud: '4',
            descripcion: 'Alta',
          ),
        ],
      ),
    );

    final restored = await localStorage.cargarBorrador('RAMAL 1');

    expect(restored.responsable, 'Operador');
    expect(restored.hallazgos.single.tipo, 'Vegetación');
  });

  test('limpia borrador tras finalizar correctamente', () async {
    await localStorage.guardarBorrador(
      const DraftData(
        usuario: 'SUPER',
        tipoLinea: 'Ramal',
        seleccionLinea: 'RAMAL 2',
        responsable: 'Operador',
        puntoReferencia: '',
        estadoLinea: 'Operativa',
        hallazgos: [],
      ),
    );

    await localStorage.agregarInspeccionCompleta(
      Inspeccion(
        linea: 'RAMAL 2',
        tipoLinea: 'Ramal',
        responsable: 'Operador',
        fecha: DateTime(2026, 5, 1),
        estadoLinea: 'Operativa',
        puntoReferencia: '',
        observaciones: '',
      ),
      const [],
    );
    await localStorage.borrarBorrador();

    expect(
      localStorage.cargarBorrador('RAMAL 2'),
      throwsA(isA<StorageNotFoundException>()),
    );
  });

  test('conserva borrador ante fallo de finalización', () async {
    await localStorage.guardarBorrador(
      const DraftData(
        usuario: 'SUPER',
        tipoLinea: 'Ramal',
        seleccionLinea: 'RAMAL 3',
        responsable: 'Operador',
        puntoReferencia: '',
        estadoLinea: 'Operativa',
        hallazgos: [],
      ),
    );

    final failingStorage = LocalDatabaseStorage(
      database: database,
      inspeccionesMemoria: memoria,
      failWrites: true,
    );

    await expectLater(
      failingStorage.agregarInspeccionCompleta(
        Inspeccion(
          linea: 'RAMAL 3',
          tipoLinea: 'Ramal',
          responsable: 'Operador',
          fecha: DateTime(2026, 5, 1),
          estadoLinea: 'Operativa',
          puntoReferencia: '',
          observaciones: '',
        ),
        const [],
      ),
      throwsA(isA<StorageWriteException>()),
    );

    final restored = await localStorage.cargarBorrador('RAMAL 3');
    expect(restored.seleccionLinea, 'RAMAL 3');
  });
}

AppRuntimeInitializer _initializer(
  LinerbDatabase database,
  LocalDatabaseStorage storage,
) {
  final service = V1DataMigrationService(target: storage);
  return AppRuntimeInitializer(
    openDatabase: () async {
      await database.open();
    },
    migrate: () async {
      await service.migrate();
      await storage.hydrateMemoryFromDatabase();
    },
  );
}

Map<String, Object> _legacyValues() {
  return {
    'historial_inspecciones': [
      jsonEncode({
        'linea': 'LÍNEA A',
        'tipoLinea': 'Troncal',
        'responsable': 'Operador',
        'fecha': DateTime(2026, 1, 2).toIso8601String(),
        'estadoLinea': 'Operativa',
        'puntoReferencia': 'KM 1',
        'observaciones': 'Sin novedad',
      }),
    ],
    'borrador_usuario': 'SUPER',
    'borrador_tipoLinea': 'Ramal',
    'borrador_seleccionLinea': 'RAMAL 1',
    'borrador_responsable': 'Operador',
    'borrador_puntoReferencia': 'KM 2',
    'borrador_estadoLinea': 'Operativa',
    'borrador_hallazgos': <String>[],
  };
}
