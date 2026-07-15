import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/core/runtime/app_runtime_initializer.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/storage/diagnostics/local_diagnostic_service.dart';
import 'package:linerb/storage/integrity/local_data_integrity_service.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:linerb/storage/local/local_database_storage.dart';
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

  test('entrega diagnóstico en estado ready', () async {
    final initializer = AppRuntimeInitializer(
      openDatabase: () async {
        await database.open();
      },
      migrate: () async {
        await storage.markMigrationCompleted('v1_shared_preferences');
      },
    );
    await initializer.initialize();
    await storage.agregarInspeccionHistorial(_inspection());
    await LocalDataIntegrityService(database: database).validateAndMark();

    final diagnostic = await LocalDiagnosticService(
      database: database,
      runtimeInitializer: initializer,
    ).collect();

    expect(diagnostic.runtimeStatus, RuntimeInitializationStatus.ready);
    expect(diagnostic.inspectionCount, 1);
    expect(diagnostic.migrationCompleted, isTrue);
    expect(diagnostic.lastValidationAt, isNotNull);
  });

  test('entrega diagnóstico en estado degraded con último error', () async {
    final initializer = AppRuntimeInitializer(
      openDatabase: () async {
        await database.open();
      },
      migrate: () {
        throw Exception('fallo diagnóstico');
      },
    );
    await initializer.initialize();

    final diagnostic = await LocalDiagnosticService(
      database: database,
      runtimeInitializer: initializer,
    ).collect();

    expect(diagnostic.runtimeStatus, RuntimeInitializationStatus.degraded);
    expect(diagnostic.lastInitializationError, isNotNull);
    expect(diagnostic.migrationCompleted, isFalse);
  });
}

Inspeccion _inspection() {
  return Inspeccion(
    linea: 'LÍNEA DIAG',
    tipoLinea: 'Troncal',
    responsable: 'Operador',
    fecha: DateTime(2026, 1, 1),
    estadoLinea: 'Operativa',
    puntoReferencia: 'KM 1',
    observaciones: 'Obs',
  );
}
