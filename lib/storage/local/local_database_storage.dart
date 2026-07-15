import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../core/utils/stable_id.dart';
import '../../models/draft_data.dart';
import '../../models/hallazgo_inspeccion.dart';
import '../../models/inspeccion.dart';
import '../../services/datos_app.dart';
import '../draft_storage.dart';
import '../inspection_storage.dart';
import '../migration/migration_target.dart';
import '../storage_exceptions.dart';
import 'linerb_database.dart';

class LocalDatabaseStorage
    implements InspectionStorage, DraftStorage, MigrationTarget {
  static const String currentDraftId = 'current';

  final LinerbDatabase database;
  final List<Inspeccion>? inspeccionesMemoria;
  final bool failWrites;

  const LocalDatabaseStorage({
    required this.database,
    this.inspeccionesMemoria,
    this.failWrites = false,
  });

  List<Inspeccion> get _inspeccionesMemoria =>
      inspeccionesMemoria ?? DatosApp.inspecciones;

  @override
  List<Inspeccion> obtenerInspeccionesMemoria() {
    return _inspeccionesMemoria;
  }

  @override
  void agregarInspeccionMemoria(Inspeccion inspeccion) {
    _inspeccionesMemoria.add(inspeccion);
  }

  @override
  DateTime? ultimaInspeccionMemoria(String linea) {
    final registros = _inspeccionesMemoria
        .where((i) => i.linea == linea)
        .toList();

    if (registros.isEmpty) return null;

    registros.sort((a, b) => b.fecha.compareTo(a.fecha));
    return registros.first.fecha;
  }

  @override
  Future<List<Inspeccion>> cargarHistorial() async {
    try {
      final db = await database.open();
      final rows = await db.query('inspections', orderBy: 'created_order ASC');

      if (rows.isEmpty) {
        throw const StorageNotFoundException('No existen inspecciones locales');
      }

      return rows.map(_inspeccionDesdeRow).toList();
    } on StorageException {
      rethrow;
    } catch (e) {
      throw StorageReadException('No se pudo leer inspecciones locales', e);
    }
  }

  @override
  Future<void> agregarInspeccionHistorial(Inspeccion inspeccion) async {
    return agregarInspeccionCompleta(inspeccion, const []);
  }

  @override
  Future<void> agregarInspeccionCompleta(
    Inspeccion inspeccion,
    List<HallazgoInspeccion> hallazgos,
  ) async {
    if (failWrites) {
      throw const StorageWriteException('Fallo simulado de escritura local');
    }

    try {
      final db = await database.open();
      final createdOrder = await _nextInspectionOrder();
      final id = StableId.fromParts('db_inspection', [
        inspeccion.linea,
        inspeccion.tipoLinea,
        inspeccion.responsable,
        inspeccion.fecha.toIso8601String(),
        inspeccion.estadoLinea,
        inspeccion.puntoReferencia,
        inspeccion.observaciones,
      ]);

      await db.transaction((txn) async {
        final inserted = await txn.insert('inspections', {
          'id': id,
          'linea': inspeccion.linea,
          'tipo_linea': inspeccion.tipoLinea,
          'responsable': inspeccion.responsable,
          'fecha_iso': inspeccion.fecha.toIso8601String(),
          'estado_linea': inspeccion.estadoLinea,
          'punto_referencia': inspeccion.puntoReferencia,
          'observaciones': inspeccion.observaciones,
          'source': 'app',
          'source_key': null,
          'created_order': createdOrder,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        if (inserted != 0) {
          for (var index = 0; index < hallazgos.length; index++) {
            await txn.insert(
              'hallazgos',
              _hallazgoToRow(hallazgos[index], index, inspectionId: id),
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      });
    } catch (e) {
      throw StorageWriteException('No se pudo guardar inspección local', e);
    }
  }

  @override
  Future<void> guardarBorrador(DraftData borrador) async {
    if (failWrites) {
      throw const StorageWriteException('Fallo simulado de escritura local');
    }

    try {
      final db = await database.open();

      await db.transaction((txn) async {
        await txn.delete(
          'hallazgos',
          where: 'draft_id = ?',
          whereArgs: [currentDraftId],
        );
        await txn.delete('draft', where: 'id = ?', whereArgs: [currentDraftId]);

        await txn.insert('draft', {
          'id': currentDraftId,
          'usuario': borrador.usuario,
          'tipo_linea': borrador.tipoLinea,
          'seleccion_linea': borrador.seleccionLinea,
          'responsable': borrador.responsable,
          'punto_referencia': borrador.puntoReferencia,
          'estado_linea': borrador.estadoLinea,
          'updated_at': DateTime.now().toIso8601String(),
        });

        for (var index = 0; index < borrador.hallazgos.length; index++) {
          await txn.insert(
            'hallazgos',
            _hallazgoToRow(
              borrador.hallazgos[index],
              index,
              draftId: currentDraftId,
            ),
          );
        }
      });
    } catch (e) {
      throw StorageWriteException('No se pudo guardar borrador local', e);
    }
  }

  @override
  Future<DraftData> cargarBorrador(String seleccionLinea) async {
    try {
      final db = await database.open();
      final draftRows = await db.query(
        'draft',
        where: 'id = ? AND seleccion_linea = ?',
        whereArgs: [currentDraftId, seleccionLinea],
        limit: 1,
      );

      if (draftRows.isEmpty) {
        throw const StorageNotFoundException('No existe borrador local');
      }

      final hallazgoRows = await db.query(
        'hallazgos',
        where: 'draft_id = ?',
        whereArgs: [currentDraftId],
        orderBy: 'created_order ASC',
      );

      final draft = draftRows.single;

      return DraftData(
        usuario: draft['usuario'] as String,
        tipoLinea: draft['tipo_linea'] as String,
        seleccionLinea: draft['seleccion_linea'] as String,
        responsable: draft['responsable'] as String,
        puntoReferencia: draft['punto_referencia'] as String,
        estadoLinea: draft['estado_linea'] as String,
        hallazgos: hallazgoRows.map(_hallazgoDesdeRow).toList(),
      );
    } on StorageException {
      rethrow;
    } catch (e) {
      throw StorageReadException('No se pudo leer borrador local', e);
    }
  }

  @override
  Future<void> borrarBorrador() async {
    if (failWrites) {
      throw const StorageWriteException('Fallo simulado de escritura local');
    }

    try {
      final db = await database.open();

      await db.transaction((txn) async {
        await txn.delete(
          'hallazgos',
          where: 'draft_id = ?',
          whereArgs: [currentDraftId],
        );
        await txn.delete('draft', where: 'id = ?', whereArgs: [currentDraftId]);
      });
    } catch (e) {
      throw StorageWriteException('No se pudo borrar borrador local', e);
    }
  }

  @override
  Future<bool> isMigrationCompleted(String key) async {
    final db = await database.open();
    final rows = await db.query(
      'migration_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    return rows.isNotEmpty && rows.single['value'] == 'completed';
  }

  @override
  Future<void> markMigrationCompleted(String key) async {
    final db = await database.open();
    await db.insert('migration_metadata', {
      'key': key,
      'value': 'completed',
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> saveLegacyInspection({
    required String id,
    required String sourceKey,
    required int createdOrder,
    required Inspeccion inspeccion,
  }) async {
    if (failWrites) {
      throw const StorageWriteException('Fallo simulado de migración');
    }

    final db = await database.open();
    final inserted = await db.insert('inspections', {
      'id': id,
      'linea': inspeccion.linea,
      'tipo_linea': inspeccion.tipoLinea,
      'responsable': inspeccion.responsable,
      'fecha_iso': inspeccion.fecha.toIso8601String(),
      'estado_linea': inspeccion.estadoLinea,
      'punto_referencia': inspeccion.puntoReferencia,
      'observaciones': inspeccion.observaciones,
      'source': 'v1_shared_preferences',
      'source_key': sourceKey,
      'created_order': createdOrder,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    return inserted != 0;
  }

  @override
  Future<void> saveMigratedDraft(DraftData draft) {
    return guardarBorrador(draft);
  }

  Future<int> inspectionCount() async {
    final db = await database.open();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM inspections',
    );
    return result.single['total'] as int;
  }

  Future<int> hallazgoCount() async {
    final db = await database.open();
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM hallazgos');
    return result.single['total'] as int;
  }

  Future<int> hallazgoCountForInspection(String linea) async {
    final db = await database.open();
    final result = await db.rawQuery(
      '''
SELECT COUNT(h.id) AS total
FROM hallazgos h
INNER JOIN inspections i ON i.id = h.inspection_id
WHERE i.linea = ?
''',
      [linea],
    );
    return result.single['total'] as int;
  }

  Future<void> hydrateMemoryFromDatabase() async {
    try {
      final historial = await cargarHistorial();
      for (final inspeccion in historial) {
        if (!_containsInspection(inspeccion)) {
          _inspeccionesMemoria.add(inspeccion);
        }
      }
    } on StorageNotFoundException {
      // Sin historial local todavía.
    }
  }

  Future<int> _nextInspectionOrder() async {
    final db = await database.open();
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(created_order), -1) + 1 AS next_order FROM inspections',
    );
    return result.single['next_order'] as int;
  }

  Inspeccion _inspeccionDesdeRow(Map<String, Object?> row) {
    return Inspeccion(
      linea: row['linea'] as String,
      tipoLinea: row['tipo_linea'] as String,
      responsable: row['responsable'] as String,
      fecha: DateTime.parse(row['fecha_iso'] as String),
      estadoLinea: row['estado_linea'] as String,
      puntoReferencia: row['punto_referencia'] as String,
      observaciones: row['observaciones'] as String,
    );
  }

  Map<String, Object?> _hallazgoToRow(
    HallazgoInspeccion hallazgo,
    int index, {
    String? draftId,
    String? inspectionId,
  }) {
    return {
      'id': StableId.fromParts('hallazgo', [
        draftId,
        inspectionId,
        index,
        hallazgo.tipo,
        hallazgo.detalle,
        hallazgo.latitud,
        hallazgo.longitud,
        hallazgo.descripcion,
        hallazgo.foto1Path,
        hallazgo.foto2Path,
      ]),
      'inspection_id': inspectionId,
      'draft_id': draftId,
      'tipo': hallazgo.tipo,
      'detalle': hallazgo.detalle,
      'latitud': hallazgo.latitud,
      'longitud': hallazgo.longitud,
      'descripcion': hallazgo.descripcion,
      'foto1_path': hallazgo.foto1Path,
      'foto2_path': hallazgo.foto2Path,
      'created_order': index,
    };
  }

  HallazgoInspeccion _hallazgoDesdeRow(Map<String, Object?> row) {
    return HallazgoInspeccion(
      tipo: row['tipo'] as String,
      detalle: row['detalle'] as String,
      latitud: row['latitud'] as String,
      longitud: row['longitud'] as String,
      descripcion: row['descripcion'] as String,
      foto1Path: row['foto1_path'] as String?,
      foto2Path: row['foto2_path'] as String?,
    );
  }

  bool _containsInspection(Inspeccion inspeccion) {
    return _inspeccionesMemoria.any((item) {
      return item.linea == inspeccion.linea &&
          item.tipoLinea == inspeccion.tipoLinea &&
          item.responsable == inspeccion.responsable &&
          item.fecha == inspeccion.fecha &&
          item.estadoLinea == inspeccion.estadoLinea &&
          item.puntoReferencia == inspeccion.puntoReferencia &&
          item.observaciones == inspeccion.observaciones;
    });
  }
}
