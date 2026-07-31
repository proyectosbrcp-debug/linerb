import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/sync_batch_config.dart';
import '../../models/sync_models.dart';
import '../sync_repository.dart';
import 'finding_remote_mapper.dart';
import 'inspection_remote_mapper.dart';

class FirestoreRemoteSyncDataSource implements RemoteSyncDataSource {
  final FirebaseFirestore firestore;
  final InspectionRemoteMapper inspectionMapper;
  final FindingRemoteMapper findingMapper;

  const FirestoreRemoteSyncDataSource({
    required this.firestore,
    this.inspectionMapper = const InspectionRemoteMapper(),
    this.findingMapper = const FindingRemoteMapper(),
  });

  @override
  Future<void> push(SyncQueueEntry operation) async {
    final payload = _decode(operation.payloadJson);

    switch ((operation.entityType, operation.operation)) {
      case (SyncEntityType.inspection, SyncOperationType.create):
        return createInspection(payload);
      case (SyncEntityType.inspection, SyncOperationType.update):
        return updateInspection(payload);
      case (SyncEntityType.inspection, SyncOperationType.delete):
        return deleteInspection(payload);
      case (SyncEntityType.finding, SyncOperationType.create):
        return createFinding(payload);
      case (SyncEntityType.finding, SyncOperationType.update):
        return updateFinding(payload);
      case (SyncEntityType.finding, SyncOperationType.delete):
        return deleteFinding(payload);
    }
  }

  @override
  Future<void> pushBatch(List<SyncQueueEntry> operations) async {
    final batch = firestore.batch();
    for (final operation in operations) {
      _addToBatch(batch, operation);
    }
    await batch.commit();
  }

  @override
  Future<void> createInspection(Map<String, Object?> payload) async {
    final remote = inspectionMapper.fromLocalPayload(payload);
    await _inspectionRef(remote['global_id'] as String).set(remote);
  }

  @override
  Future<void> updateInspection(Map<String, Object?> payload) async {
    final remote = inspectionMapper.fromLocalPayload(payload);
    await _inspectionRef(
      remote['global_id'] as String,
    ).set(remote, SetOptions(merge: true));
  }

  @override
  Future<void> deleteInspection(Map<String, Object?> payload) async {
    final remote = inspectionMapper.fromLocalPayload(payload);
    await _inspectionRef(remote['global_id'] as String).set({
      'global_id': remote['global_id'],
      'deleted_at': remote['deleted_at'] ?? Timestamp.now(),
      'updated_at': remote['updated_at'] ?? Timestamp.now(),
      'remote_version': remote['remote_version'],
    }, SetOptions(merge: true));
  }

  @override
  Future<void> createFinding(Map<String, Object?> payload) async {
    final remote = findingMapper.fromLocalPayload(payload);
    await _findingRef(remote['global_id'] as String).set(remote);
  }

  @override
  Future<void> updateFinding(Map<String, Object?> payload) async {
    final remote = findingMapper.fromLocalPayload(payload);
    await _findingRef(
      remote['global_id'] as String,
    ).set(remote, SetOptions(merge: true));
  }

  @override
  Future<void> deleteFinding(Map<String, Object?> payload) async {
    final remote = findingMapper.fromLocalPayload(payload);
    await _findingRef(remote['global_id'] as String).set({
      'global_id': remote['global_id'],
      'inspection_global_id': remote['inspection_global_id'],
      'deleted_at': remote['deleted_at'] ?? Timestamp.now(),
      'updated_at': remote['updated_at'] ?? Timestamp.now(),
      'remote_version': remote['remote_version'],
    }, SetOptions(merge: true));
  }

  @override
  Future<RemoteChangeSet> fetchChanges({
    DateTime? since,
    RemoteSyncCursors? cursors,
  }) async {
    final legacyCursor = since == null
        ? null
        : SyncCursor(updatedAt: since, globalId: '');
    final inspectionCursor = cursors?.inspections ?? legacyCursor;
    final findingCursor = cursors?.findings ?? legacyCursor;

    final inspectionResult = await _fetchCollectionChanges(
      collection: 'inspections',
      cursor: inspectionCursor,
      mapper: inspectionMapper.fromRemote,
    );
    final findingResult = await _fetchCollectionChanges(
      collection: 'findings',
      cursor: findingCursor,
      mapper: findingMapper.fromRemote,
    );

    return RemoteChangeSet(
      inspections: inspectionResult.items,
      findings: findingResult.items,
      cursor: inspectionResult.cursor?.updatedAt ?? since,
      inspectionsCursor: inspectionResult.cursor,
      findingsCursor: findingResult.cursor,
    );
  }

  @override
  Future<List<Map<String, Object?>>> fetchFindingsForInspections(
    List<String> inspectionGlobalIds,
  ) async {
    final findings = <Map<String, Object?>>[];
    for (final chunk in _chunks(inspectionGlobalIds, 10)) {
      if (chunk.isEmpty) continue;
      final snapshot = await firestore
          .collection('findings')
          .where('inspection_global_id', whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        final mapped = findingMapper.fromRemote(doc.data());
        if (mapped != null) findings.add(mapped);
      }
    }
    return findings;
  }

  void _addToBatch(WriteBatch batch, SyncQueueEntry operation) {
    final payload = _decode(operation.payloadJson);
    if (operation.entityType == SyncEntityType.inspection) {
      final remote = inspectionMapper.fromLocalPayload(payload);
      batch.set(
        _inspectionRef(remote['global_id'] as String),
        remote,
        SetOptions(merge: operation.operation != SyncOperationType.create),
      );
      return;
    }

    final remote = findingMapper.fromLocalPayload(payload);
    batch.set(
      _findingRef(remote['global_id'] as String),
      remote,
      SetOptions(merge: operation.operation != SyncOperationType.create),
    );
  }

  DocumentReference<Map<String, dynamic>> _inspectionRef(String globalId) {
    return firestore.collection('inspections').doc(globalId);
  }

  DocumentReference<Map<String, dynamic>> _findingRef(String findingGlobalId) {
    return firestore.collection('findings').doc(findingGlobalId);
  }

  Map<String, Object?> _decode(String payloadJson) {
    return Map<String, Object?>.from(jsonDecode(payloadJson) as Map);
  }

  Future<_CollectionChanges> _fetchCollectionChanges({
    required String collection,
    required SyncCursor? cursor,
    required Map<String, Object?>? Function(Map<String, Object?> data) mapper,
  }) async {
    final limit = collection == 'findings'
        ? SyncBatchConfig.pullFindingsLimit
        : SyncBatchConfig.pullInspectionsLimit;
    Query<Map<String, dynamic>> query = firestore
        .collection(collection)
        .orderBy('updated_at')
        .orderBy('global_id')
        .limit(limit);
    if (cursor != null) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.updatedAt),
        cursor.globalId,
      ]);
    }

    final snapshot = await query.get();
    final items = <Map<String, Object?>>[];
    var nextCursor = cursor;

    for (final doc in snapshot.docs) {
      final mapped = mapper(doc.data());
      if (mapped == null) continue;
      final globalId = mapped['global_id'];
      final updatedAt = mapped['updated_at'];
      if (globalId is! String || updatedAt is! Timestamp) continue;
      final updatedDate = updatedAt.toDate();
      if (cursor != null && !cursor.isBeforeRemote(updatedDate, globalId)) {
        continue;
      }
      items.add(mapped);
      nextCursor = _maxCursor(
        nextCursor,
        SyncCursor(updatedAt: updatedDate, globalId: globalId),
      );
    }

    return _CollectionChanges(items: items, cursor: nextCursor);
  }

  SyncCursor _maxCursor(SyncCursor? current, SyncCursor candidate) {
    if (current == null ||
        current.isBeforeRemote(candidate.updatedAt, candidate.globalId)) {
      return candidate;
    }
    return current;
  }

  Iterable<List<String>> _chunks(List<String> values, int size) sync* {
    for (var index = 0; index < values.length; index += size) {
      yield values.sublist(
        index,
        index + size > values.length ? values.length : index + size,
      );
    }
  }
}

class _CollectionChanges {
  final List<Map<String, Object?>> items;
  final SyncCursor? cursor;

  const _CollectionChanges({required this.items, required this.cursor});
}
