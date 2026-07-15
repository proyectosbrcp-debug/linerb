import 'package:cloud_firestore/cloud_firestore.dart';

import 'remote_mapping_exception.dart';

class InspectionRemoteMapper {
  static const allowedFields = {
    'global_id',
    'fecha',
    'responsable',
    'usuario',
    'tipo_linea',
    'linea',
    'subtroncal',
    'punto_referencia',
    'estado_linea',
    'observacion_general',
    'created_at',
    'updated_at',
    'created_by',
    'updated_by',
    'device_id',
    'local_version',
    'remote_version',
    'sync_status',
    'deleted_at',
  };

  const InspectionRemoteMapper();

  Map<String, Object?> fromLocalPayload(Map<String, Object?> local) {
    _rejectForbidden(local);
    final globalId = _requiredString(local, 'global_id');
    final localVersion = _requiredInt(local, 'local_version');
    final remoteVersion = _requiredInt(local, 'remote_version');

    if (globalId.isEmpty) {
      throw const RemoteMappingException('global_id vacío');
    }
    if (localVersion < 0 || remoteVersion < 0) {
      throw const RemoteMappingException('versiones inválidas');
    }

    final payload = <String, Object?>{
      'global_id': globalId,
      'fecha': _timestamp(local['fecha_iso']),
      'responsable': local['responsable'] ?? '',
      'usuario': local['created_by'] ?? '',
      'tipo_linea': local['tipo_linea'] ?? '',
      'linea': local['linea'] ?? '',
      'subtroncal': _subtroncal(local['linea']),
      'punto_referencia': local['punto_referencia'] ?? '',
      'estado_linea': local['estado_linea'] ?? '',
      'observacion_general': local['observaciones'] ?? '',
      'created_at': _timestamp(local['created_at']),
      'updated_at': _timestamp(local['updated_at']),
      'created_by': local['created_by'] ?? '',
      'updated_by': local['updated_by'] ?? '',
      'device_id': local['device_id'] ?? '',
      'local_version': localVersion,
      'remote_version': remoteVersion,
      'sync_status': local['sync_status'] ?? 'pendingCreate',
      'deleted_at': _nullableTimestamp(local['deleted_at']),
    };

    return _onlyAllowed(payload);
  }

  Map<String, Object?>? fromRemote(Map<String, Object?> remote) {
    try {
      final globalId = remote['global_id'];
      if (globalId is! String || globalId.isEmpty) return null;
      return _onlyAllowed(remote);
    } catch (_) {
      return null;
    }
  }

  void _rejectForbidden(Map<String, Object?> data) {
    const forbiddenFragments = [
      'foto',
      'photo',
      'image',
      'base64',
      'pdf',
      'file',
      'path',
      'ruta',
      'draft',
      'borrador',
    ];

    for (final key in data.keys) {
      final normalized = key.toLowerCase();
      if (forbiddenFragments.any(normalized.contains)) {
        throw RemoteMappingException('Campo local no permitido: $key');
      }
    }
  }

  Map<String, Object?> _onlyAllowed(Map<String, Object?> payload) {
    return Map.fromEntries(
      payload.entries.where((entry) => allowedFields.contains(entry.key)),
    );
  }

  String _requiredString(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is String) return value;
    throw RemoteMappingException('$key requerido');
  }

  int _requiredInt(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is int) return value;
    throw RemoteMappingException('$key requerido');
  }

  Timestamp _timestamp(Object? value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is String && value.isNotEmpty) {
      return Timestamp.fromDate(DateTime.parse(value));
    }
    throw const RemoteMappingException('fecha requerida');
  }

  Timestamp? _nullableTimestamp(Object? value) {
    if (value == null) return null;
    if (value is String && value.isEmpty) return null;
    return _timestamp(value);
  }

  String? _subtroncal(Object? line) {
    if (line is! String || !line.contains('/')) return null;
    final parts = line.split('/');
    if (parts.length < 2) return null;
    return parts.last.trim();
  }
}
