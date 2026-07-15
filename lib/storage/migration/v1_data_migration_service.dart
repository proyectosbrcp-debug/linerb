import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/stable_id.dart';
import '../../models/draft_data.dart';
import '../../models/hallazgo_inspeccion.dart';
import '../../models/inspeccion.dart';
import 'migration_target.dart';

class MigrationReport {
  final bool alreadyCompleted;
  final bool completed;
  final int migrated;
  final int skipped;
  final int failed;
  final List<String> messages;

  const MigrationReport({
    required this.alreadyCompleted,
    required this.completed,
    required this.migrated,
    required this.skipped,
    required this.failed,
    required this.messages,
  });
}

class V1DataMigrationService {
  static const String migrationKey = 'v1_shared_preferences';

  final MigrationTarget target;
  final Future<SharedPreferences> Function() preferencesFactory;

  const V1DataMigrationService({
    required this.target,
    this.preferencesFactory = SharedPreferences.getInstance,
  });

  Future<MigrationReport> migrate() async {
    final messages = <String>[];

    if (await target.isMigrationCompleted(migrationKey)) {
      return const MigrationReport(
        alreadyCompleted: true,
        completed: true,
        migrated: 0,
        skipped: 0,
        failed: 0,
        messages: ['La migración V1 ya estaba registrada como completa.'],
      );
    }

    final prefs = await preferencesFactory();
    var migrated = 0;
    var skipped = 0;
    var failed = 0;

    final historial = prefs.getStringList('historial_inspecciones') ?? [];

    for (var index = 0; index < historial.length; index++) {
      final raw = historial[index];
      final parsed = _tryParseInspection(raw);

      if (parsed == null) {
        skipped++;
        messages.add('Inspección V1 omitida por dato corrupto o incompleto.');
        continue;
      }

      try {
        final id = StableId.fromJson('v1_inspection', raw);
        final inserted = await target.saveLegacyInspection(
          id: id,
          sourceKey: 'historial_inspecciones:$id',
          createdOrder: index,
          inspeccion: parsed,
        );

        if (inserted) {
          migrated++;
        } else {
          skipped++;
          messages.add('Inspección V1 omitida por duplicado: $id');
        }
      } catch (e) {
        failed++;
        messages.add('Falló la migración de una inspección V1: $e');
      }
    }

    final draft = _tryReadDraft(prefs, messages);
    if (draft == null) {
      skipped++;
    } else {
      try {
        await target.saveMigratedDraft(draft);
        migrated++;
      } catch (e) {
        failed++;
        messages.add('Falló la migración del borrador V1: $e');
      }
    }

    final completed = failed == 0;
    if (completed) {
      await target.markMigrationCompleted(migrationKey);
    }

    return MigrationReport(
      alreadyCompleted: false,
      completed: completed,
      migrated: migrated,
      skipped: skipped,
      failed: failed,
      messages: messages,
    );
  }

  Inspeccion? _tryParseInspection(String raw) {
    try {
      final data = jsonDecode(raw);
      final linea = data['linea'];
      final tipoLinea = data['tipoLinea'];
      final responsable = data['responsable'];
      final fecha = data['fecha'];
      final estadoLinea = data['estadoLinea'];
      final puntoReferencia = data['puntoReferencia'];
      final observaciones = data['observaciones'];

      if (linea is! String ||
          tipoLinea is! String ||
          responsable is! String ||
          fecha is! String ||
          estadoLinea is! String ||
          puntoReferencia is! String ||
          observaciones is! String) {
        return null;
      }

      return Inspeccion(
        linea: linea,
        tipoLinea: tipoLinea,
        responsable: responsable,
        fecha: DateTime.parse(fecha),
        estadoLinea: estadoLinea,
        puntoReferencia: puntoReferencia,
        observaciones: observaciones,
      );
    } catch (_) {
      return null;
    }
  }

  DraftData? _tryReadDraft(SharedPreferences prefs, List<String> messages) {
    final seleccionLinea = prefs.getString('borrador_seleccionLinea');
    if (seleccionLinea == null) {
      messages.add('No existe borrador V1 para migrar.');
      return null;
    }

    final hallazgos = <HallazgoInspeccion>[];
    final hallazgosJson = prefs.getStringList('borrador_hallazgos') ?? [];

    for (final item in hallazgosJson) {
      try {
        final data = jsonDecode(item);
        hallazgos.add(
          HallazgoInspeccion(
            tipo: data['tipo'] ?? '',
            detalle: data['detalle'] ?? '',
            latitud: data['latitud'] ?? '',
            longitud: data['longitud'] ?? '',
            descripcion: data['descripcion'] ?? '',
            foto1Path: data['foto1Path'],
            foto2Path: data['foto2Path'],
          ),
        );
      } catch (e) {
        messages.add('Hallazgo de borrador V1 omitido por JSON corrupto: $e');
      }
    }

    return DraftData(
      usuario: prefs.getString('borrador_usuario') ?? '',
      tipoLinea: prefs.getString('borrador_tipoLinea') ?? '',
      seleccionLinea: seleccionLinea,
      responsable: prefs.getString('borrador_responsable') ?? '',
      puntoReferencia: prefs.getString('borrador_puntoReferencia') ?? '',
      estadoLinea: prefs.getString('borrador_estadoLinea') ?? 'Operativa',
      hallazgos: hallazgos,
    );
  }
}
