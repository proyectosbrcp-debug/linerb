import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/core/time/app_clock.dart';
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/models/inspection_local_photos.dart';
import 'package:linerb/repositories/remote/finding_remote_mapper.dart';
import 'package:linerb/repositories/remote/remote_mapping_exception.dart';
import 'package:linerb/services/local_photo_service.dart';
import 'package:linerb/storage/local/file_local_photo_storage.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:linerb/storage/local/local_database_storage.dart';
import 'package:linerb/storage/local/local_sync_queue_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempRoot;
  late _FixedClock clock;
  late LocalPhotoService service;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('linerb_photo_test_');
    clock = _FixedClock(DateTime(2026, 6, 1, 10));
    service = LocalPhotoService(
      rootDirectoryProvider: () async => tempRoot,
      storage: FileLocalPhotoStorage(
        rootDirectoryProvider: () async => tempRoot,
      ),
      clock: clock,
    );
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('captura y almacena Foto 1 en carpeta administrada', () async {
    final source = await _temporaryImage('foto1');

    final stored = await service.storeCapturedPhoto(
      ownerId: 'inspection-a',
      slot: LocalPhotoSlot.photo1,
      temporaryPath: source.path,
    );

    expect(await File(stored).exists(), isTrue);
    expect(await source.exists(), isFalse);
    final references = await service.loadReferences('inspection-a');
    expect(references!.photo1LocalPath, stored);
    expect(references.photo2LocalPath, isNull);
  });

  test('captura y almacena Foto 2 en carpeta administrada', () async {
    final source = await _temporaryImage('foto2');

    final stored = await service.storeCapturedPhoto(
      ownerId: 'inspection-a',
      slot: LocalPhotoSlot.photo2,
      temporaryPath: source.path,
    );

    final references = await service.loadReferences('inspection-a');
    expect(await File(stored).exists(), isTrue);
    expect(references!.photo2LocalPath, stored);
    expect(references.photo1LocalPath, isNull);
  });

  test('reemplaza Foto 1 sin conservar archivo anterior', () async {
    final first = await service.storeCapturedPhoto(
      ownerId: 'inspection-a',
      slot: LocalPhotoSlot.photo1,
      temporaryPath: (await _temporaryImage('foto1-old')).path,
    );
    clock.value = DateTime(2026, 6, 1, 11);

    final second = await service.storeCapturedPhoto(
      ownerId: 'inspection-a',
      slot: LocalPhotoSlot.photo1,
      temporaryPath: (await _temporaryImage('foto1-new')).path,
      previousPath: first,
    );

    final references = await service.loadReferences('inspection-a');
    expect(await File(first).exists(), isFalse);
    expect(await File(second).exists(), isTrue);
    expect(references!.photo1LocalPath, second);
  });

  test('reemplaza Foto 2 sin conservar archivo anterior', () async {
    final first = await service.storeCapturedPhoto(
      ownerId: 'inspection-a',
      slot: LocalPhotoSlot.photo2,
      temporaryPath: (await _temporaryImage('foto2-old')).path,
    );
    clock.value = DateTime(2026, 6, 1, 11);

    final second = await service.storeCapturedPhoto(
      ownerId: 'inspection-a',
      slot: LocalPhotoSlot.photo2,
      temporaryPath: (await _temporaryImage('foto2-new')).path,
      previousPath: first,
    );

    final references = await service.loadReferences('inspection-a');
    expect(await File(first).exists(), isFalse);
    expect(await File(second).exists(), isTrue);
    expect(references!.photo2LocalPath, second);
  });

  test('rechaza una tercera fotografía', () {
    expect(() => localPhotoSlotFromNumber(3), throwsRangeError);
  });

  test('restaura rutas desde borrador cuando existen', () async {
    final photo1 = await service.storeCapturedPhoto(
      ownerId: 'draft-a',
      slot: LocalPhotoSlot.photo1,
      temporaryPath: (await _temporaryImage('draft-1')).path,
    );
    final photo2 = await service.storeCapturedPhoto(
      ownerId: 'draft-a',
      slot: LocalPhotoSlot.photo2,
      temporaryPath: (await _temporaryImage('draft-2')).path,
    );

    final sanitized = await service.sanitizeHallazgoPhotos(
      _finding(photo1, photo2),
    );

    expect(sanitized.foto1Path, photo1);
    expect(sanitized.foto2Path, photo2);
  });

  test(
    'archivo local inexistente marca solo ese espacio como pendiente',
    () async {
      final photo2 = await service.storeCapturedPhoto(
        ownerId: 'draft-a',
        slot: LocalPhotoSlot.photo2,
        temporaryPath: (await _temporaryImage('draft-2')).path,
      );

      final sanitized = await service.sanitizeHallazgoPhotos(
        _finding('${tempRoot.path}/missing.jpg', photo2),
      );

      expect(sanitized.foto1Path, isNull);
      expect(sanitized.foto2Path, photo2);
    },
  );

  test(
    'conserva fotos locales si falla la finalización estructurada',
    () async {
      final photo1 = await service.storeCapturedPhoto(
        ownerId: 'inspection-a',
        slot: LocalPhotoSlot.photo1,
        temporaryPath: (await _temporaryImage('fail-1')).path,
      );
      final database = LinerbDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final storage = LocalDatabaseStorage(
        database: database,
        failWrites: true,
      );

      expect(
        storage.agregarInspeccionCompleta(_inspection(), [
          _finding(photo1, null),
        ]),
        throwsA(isA<Exception>()),
      );
      expect(await File(photo1).exists(), isTrue);
      await database.close();
    },
  );

  test('PDF recibe exactamente dos rutas locales existentes', () async {
    final photo1 = await service.storeCapturedPhoto(
      ownerId: 'pdf-a',
      slot: LocalPhotoSlot.photo1,
      temporaryPath: (await _temporaryImage('pdf-1')).path,
    );
    final photo2 = await service.storeCapturedPhoto(
      ownerId: 'pdf-a',
      slot: LocalPhotoSlot.photo2,
      temporaryPath: (await _temporaryImage('pdf-2')).path,
    );

    final paths = await service.pdfPhotoPaths(_finding(photo1, photo2));

    expect(paths, hasLength(2));
    expect(paths, [photo1, photo2]);
  });

  test('funciona completamente offline', () async {
    final stored = await service.storeCapturedPhoto(
      ownerId: 'offline-a',
      slot: LocalPhotoSlot.photo1,
      temporaryPath: (await _temporaryImage('offline')).path,
    );

    expect(await File(stored).exists(), isTrue);
  });

  test('fotos y PDF quedan excluidos de sync_queue', () async {
    final database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final queue = LocalSyncQueueStorage(database: database, clock: clock);
    final storage = LocalDatabaseStorage(
      database: database,
      inspeccionesMemoria: [],
      clock: clock,
      syncQueueStorage: queue,
    );

    await storage.agregarInspeccionCompleta(_inspection(), [
      _finding('/local/photo1.jpg', '/local/photo2.jpg'),
    ]);

    final payload = (await queue.pendingOperations())
        .map((entry) => entry.payloadJson)
        .join('|');

    expect(payload, isNot(contains('photo')));
    expect(payload, isNot(contains('foto')));
    expect(payload, isNot(contains('/local')));
    expect(payload, isNot(contains('pdf')));
    await database.close();
  });

  test('mapeadores remotos rechazan rutas y PDF', () {
    const mapper = FindingRemoteMapper();

    expect(
      () => mapper.fromLocalPayload({
        'global_id': 'finding-1',
        'inspection_id': 'inspection-1',
        'tipo': 'Fuga',
        'detalle': 'Leve',
        'descripcion': 'Hallazgo',
        'latitud': '1',
        'longitud': '2',
        'created_at': DateTime(2026, 6, 1).toIso8601String(),
        'updated_at': DateTime(2026, 6, 1).toIso8601String(),
        'created_by': 'local',
        'updated_by': 'local',
        'device_id': 'device',
        'local_version': 1,
        'remote_version': 0,
        'photo1LocalPath': '/local/photo1.jpg',
      }),
      throwsA(isA<RemoteMappingException>()),
    );
  });

  test('dashboard puede leer datos aunque no existan fotografías', () async {
    final database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final storage = LocalDatabaseStorage(
      database: database,
      inspeccionesMemoria: [],
      clock: clock,
    );

    await storage.agregarInspeccionCompleta(_inspection(), [
      _finding(
        '${tempRoot.path}/missing1.jpg',
        '${tempRoot.path}/missing2.jpg',
      ),
    ]);

    expect(await storage.inspectionCount(), 1);
    await database.close();
  });

  test('Firebase Storage no está declarado como dependencia', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    expect(pubspec, isNot(contains('firebase_storage')));
  });

  test('aísla fotografías entre inspecciones', () async {
    final first = await service.storeCapturedPhoto(
      ownerId: 'inspection-a',
      slot: LocalPhotoSlot.photo1,
      temporaryPath: (await _temporaryImage('a')).path,
    );
    final second = await service.storeCapturedPhoto(
      ownerId: 'inspection-b',
      slot: LocalPhotoSlot.photo1,
      temporaryPath: (await _temporaryImage('b')).path,
    );

    expect(first, isNot(second));
    expect(first, contains('inspection-a'));
    expect(second, contains('inspection-b'));
  });
}

Future<File> _temporaryImage(String name) async {
  final file = File('${Directory.systemTemp.path}/$name.jpg');
  await file.writeAsBytes([1, 2, 3, 4]);
  return file;
}

Inspeccion _inspection() {
  return Inspeccion(
    linea: 'RAMAL 1',
    tipoLinea: 'Ramal',
    responsable: 'Operador',
    fecha: DateTime(2026, 6, 1),
    estadoLinea: 'Operativa',
    puntoReferencia: 'KM 1',
    observaciones: 'Sin novedad',
  );
}

HallazgoInspeccion _finding(String? photo1, String? photo2) {
  return HallazgoInspeccion(
    tipo: 'Fuga',
    detalle: 'Leve',
    latitud: '1',
    longitud: '2',
    descripcion: 'Hallazgo',
    foto1Path: photo1,
    foto2Path: photo2,
  );
}

class _FixedClock implements Clock {
  DateTime value;

  _FixedClock(this.value);

  @override
  DateTime now() => value;
}
