import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/models/draft_data.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:linerb/storage/local/local_database_storage.dart';
import 'package:linerb/storage/migration/migration_target.dart';
import 'package:linerb/storage/migration/v1_data_migration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LinerbDatabase database;
  late LocalDatabaseStorage storage;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    storage = LocalDatabaseStorage(database: database, inspeccionesMemoria: []);
  });

  tearDown(() async {
    await database.close();
  });

  test('migra datos V1 válidos y conserva claves antiguas', () async {
    SharedPreferences.setMockInitialValues(_legacyValues());

    final service = V1DataMigrationService(target: storage);
    final report = await service.migrate();
    final prefs = await SharedPreferences.getInstance();

    expect(report.completed, isTrue);
    expect(report.migrated, 2);
    expect(await storage.inspectionCount(), 1);
    expect((await storage.cargarHistorial()).single.linea, 'LÍNEA A');
    expect((await storage.cargarBorrador('RAMAL 1')).hallazgos, hasLength(1));
    expect(prefs.getStringList('historial_inspecciones'), isNotNull);
    expect(prefs.getString('borrador_seleccionLinea'), 'RAMAL 1');
  });

  test('ejecutar la migración dos veces no duplica datos', () async {
    SharedPreferences.setMockInitialValues(_legacyValues());

    final service = V1DataMigrationService(target: storage);

    final first = await service.migrate();
    final second = await service.migrate();

    expect(first.completed, isTrue);
    expect(second.alreadyCompleted, isTrue);
    expect(await storage.inspectionCount(), 1);
  });

  test('omite JSON corrupto sin detener la migración', () async {
    SharedPreferences.setMockInitialValues({
      'historial_inspecciones': ['{json-corrupto'],
    });

    final service = V1DataMigrationService(target: storage);
    final report = await service.migrate();

    expect(report.completed, isTrue);
    expect(report.skipped, greaterThanOrEqualTo(1));
    expect(await storage.inspectionCount(), 0);
  });

  test('omite datos incompletos sin detener la migración', () async {
    SharedPreferences.setMockInitialValues({
      'historial_inspecciones': [
        jsonEncode({'linea': 'LÍNEA INCOMPLETA'}),
      ],
    });

    final service = V1DataMigrationService(target: storage);
    final report = await service.migrate();

    expect(report.completed, isTrue);
    expect(report.skipped, greaterThanOrEqualTo(1));
    expect(await storage.inspectionCount(), 0);
  });

  test('reporta fallo parcial y no marca migración completa', () async {
    SharedPreferences.setMockInitialValues(_legacyValues(includeDraft: false));

    final target = FailingMigrationTarget();
    final service = V1DataMigrationService(target: target);
    final report = await service.migrate();

    expect(report.completed, isFalse);
    expect(report.failed, 1);
    expect(await target.isMigrationCompleted('v1_shared_preferences'), isFalse);
  });
}

Map<String, Object> _legacyValues({bool includeDraft = true}) {
  final values = <String, Object>{
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
  };

  if (includeDraft) {
    values.addAll({
      'borrador_usuario': 'SUPER',
      'borrador_tipoLinea': 'Ramal',
      'borrador_seleccionLinea': 'RAMAL 1',
      'borrador_responsable': 'Operador',
      'borrador_puntoReferencia': 'KM 2',
      'borrador_estadoLinea': 'Operativa',
      'borrador_hallazgos': [
        jsonEncode({
          'tipo': 'Fuga',
          'detalle': 'Activa',
          'latitud': '1',
          'longitud': '2',
          'descripcion': 'Fuga visible',
          'foto1Path': null,
          'foto2Path': null,
        }),
      ],
    });
  }

  return values;
}

class FailingMigrationTarget implements MigrationTarget {
  bool completed = false;

  @override
  Future<bool> isMigrationCompleted(String key) async {
    return completed;
  }

  @override
  Future<void> markMigrationCompleted(String key) async {
    completed = true;
  }

  @override
  Future<bool> saveLegacyInspection({
    required String id,
    required String sourceKey,
    required int createdOrder,
    required Inspeccion inspeccion,
  }) async {
    throw Exception('fallo simulado');
  }

  @override
  Future<void> saveMigratedDraft(DraftData draft) async {}
}
